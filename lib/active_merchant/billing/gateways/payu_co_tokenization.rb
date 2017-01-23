module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PayuCoTokenizationGateway < Gateway
      self.test_url = 'https://stg.api.payulatam.com/payments-api/4.0/service.cgi'
      self.live_url = 'https://api.payulatam.com/payments-api/4.0/service.cgi'

      INFO_TEST_URL = 'https://stg.api.payulatam.com/reports-api/4.0/service.cgi'
      INFO_LIVE_URL = 'https://api.payulatam.com/reports-api/4.0/service.cgi'

      self.supported_countries = ['CO']
      self.default_currency = 'COP'
      self.supported_cardtypes = [:visa, :master, :american_express, :diners_club]

      self.homepage_url = 'http://payu.com.co/'
      self.display_name = 'PayU Colombia'

      STANDARD_ERROR_CODE_MAPPING = {}

      BRAND_MAP = {
        visa: "VISA",
        master: "MAST",
        american_express: "AMEX",
        diners_club: "DINR"
      }

      def initialize(options={})
        requires!(options, :key, :login, :account_id, :merchant_id)
        super
      end

      def store(creditcard, options = {})
        post = {
          language: "es",
          command: "CREATE_TOKEN",
          merchant: {},
          test: test?
        }

        add_merchant(post)
        add_credit_card_token(post, creditcard, options)

        commit("store", post)
      end

      def update(billing_id, creditcard, options = {})

        post = {
          language: "es",
          command: "REMOVE_TOKEN",
          merchant: {},
          test: test?
        }

        add_merchant(post)

        remove_credit_card_token(post, billing_id, options)

        commit("update", post)

        store(creditcard, options)
      end

      # payment = { token_id: "credit card token id", brand: "credit card brand" }
      def purchase(money, payment, options = {})

        credit_card_brand = credit_card_brand(payment, options)

        post = {
          language: "es",
          command: "SUBMIT_TRANSACTION",
          merchant: {},
          transaction: {},
          test: test?
        }

        add_merchant(post)
        add_invoice(post, money, options)
        add_payment(post, payment, credit_card_brand, options)
        add_customer_data(post, options)
        add_addresses(post, options)
        add_other_transaction_data(post, options)
        add_authorization_capture(post)

        commit("purchase", post)
      end

      # options = {order_id: "order_id", reason: "reson for the refund", transaction_id: "id of the transaction"}
      def refund(options={})
        post = {
          language: "es",
          command: "SUBMIT_TRANSACTION",
          merchant: {},
          transaction: {},
          test: test?
        }
        add_merchant(post)

        options.merge!({type: "REFUND"})

        add_transaction(post, options)

        commit("refund", post)
      end

      # options = {order_id: "order_id", reason: "reson for the cancelation", transaction_id: "id of the transaction"}
      def void(options={})
        post = {
          language: "es",
          command: "SUBMIT_TRANSACTION",
          merchant: {},
          transaction: {},
          test: test?
        }
        add_merchant(post)

        options.merge!({type: "VOID"})

        add_transaction(post, options)

        commit("void", post)
      end

      #id for the order, integer value
      def order_status(order_id)
        post = {
          test: test?,
          language: "es",
          command: "ORDER_DETAIL",
          merchant: {},
          details: {
            orderId: order_id
          }
        }

        add_merchant(post)

        commit("info", post)
      end

      private

        def add_merchant(post)
          post[:merchant][:apiKey] = @options[:key]
          post[:merchant][:apiLogin] = @options[:login]
        end

        def add_transaction(post, options)
          post[:transaction] = {
            type: options[:type],
            parentTransactionId: options[:transaction_id],
            reason: options[:reason],
            order: {}
          }
          post[:transaction][:order] = {
            id: options[:order_id]
          }
        end

        def add_invoice(post, money, options)
          reference_code = "payment_#{Time.now.to_i}"

          payu_signature = Digest::MD5.hexdigest("#{@options[:key]}~#{@options[:merchant_id]}~#{reference_code}~#{money}~COP")

          post[:transaction][:order] = {
            accountId: @options[:account_id],
            referenceCode: reference_code,
            description: "Payment",
            language: "es",
            signature: payu_signature,
            additionalValues: {
              TX_VALUE: {
                value: money,
                currency: "COP"
              }
            }
          }
        end

        def add_payment(post, payment, brand, options)
          post[:transaction]["creditCardTokenId"] = payment
          post[:transaction][:paymentMethod] = brand
          post[:transaction][:paymentCountry] = "CO"
        end

        def credit_card_brand(payment, options)
          response = token_query(payment, options)

          raise response.message if response.params["code"] == "ERROR"

          response.params["creditCardTokenList"][0]["paymentMethod"]
        end

        def token_query(billing_id, options = {})

          post = {
            language: "es",
            command: "GET_TOKENS",
            merchant: {},
            test: test?
          }

          add_merchant(post)
          add_credit_card_token_info(post, billing_id, options)

          commit("token", post)
        end

        def add_customer_data(post, options)
          if options[:user]
            post[:transaction][:payer] = {
              merchantPayerId: options[:user][:identification],
              fullName: options[:user][:full_name],
              emailAddress: options[:user][:email],
              dniNumber: options[:user][:identification]
            }

            post[:transaction][:order][:buyer] = {
              emailAddress: options[:user][:email]
            }
          end
        end

        def add_addresses(post, options)
          if options[:billing_address]
            post[:transaction][:payer]["billingAddress"] = {
              street1: clean(options[:billing_address][:street1], :text, 100),
              street2: clean(options[:billing_address][:street2], :text, 100),
              city: clean(options[:billing_address][:city], :text, 50),
              state: clean(options[:billing_address][:state], :text, 50),
              country: clean(options[:billing_address][:country], :text, 50),
              postalCode: clean(options[:billing_address][:zip], :numeric, 20),
              phone: clean(options[:billing_address][:phone], :numeric, 20)
            }
          end
        end

        def add_credit_card_token(post, creditcard, options)
          post[:creditCardToken] = {
            "payerId": options[:user][:identification],
            "name": options[:user][:full_name],
            "identificationNumber": options[:user][:identification],
            "paymentMethod": BRAND_MAP[creditcard.brand.to_sym],
            "number": creditcard.number,
            "expirationDate": "#{format(creditcard.year, :four_digits)}/#{format(creditcard.month, :two_digits)}"
          }
        end

        def remove_credit_card_token(post, billing_id, options)
          post[:removeCreditCardToken] = {
            "payerId": options[:user][:identification],
            "creditCardTokenId": billing_id
          }
        end

        def add_credit_card_token_info(post, billing_id, options)
          post[:creditCardTokenInformation] = {
            "payerId": options[:user][:identification],
            "creditCardTokenId": billing_id
          }
        end

        def add_other_transaction_data(post, options)
          post[:transaction][:extraParameters] = {INSTALLMENTS_NUMBER: 1}
        end

        def add_authorization_capture(post)
          post[:transaction][:type] = "AUTHORIZATION_AND_CAPTURE"
        end

        def clean(value, format, maxlength)
          value ||= ""
          value = case format
          when :alphanumeric
            value.gsub(/[^A-Za-z0-9]/, "")
          when :name
            value.gsub(/[^A-Za-z ]/, "")
          when :numeric
            value.gsub(/[^0-9]/, "")
          when :text
            value.gsub(/[^A-Za-z0-9@\-_\/\. ]/, "")
          when nil
            value
          else
            raise "Unknown format #{format} for #{value}"
          end
          value[0...maxlength]
        end

        def parse(body)
          top = JSON.parse(body)

          if result = top.delete("result")
            if !result.is_a?(Hash)
              result = result.split("&").inject({}) do |hash, string|
                key, value = string.split("=")
                hash[CGI.unescape(key).downcase] = CGI.unescape(value || "")
                hash
              end
            end

            result.each do |key, value|
              if top[key]
                top["result_#{key}"] = value
              else
                top[key] = value
              end
            end
          end

          if response = top.delete("response")
            top.merge!(response)
          end

          top
        rescue JSON::ParserError
          {
            "error" => "Invalid response received from the PayU API. (The raw response was `#{body}`)."
          }
        end

        def url(action)
          case action
          when "info"
            test? ? INFO_TEST_URL : INFO_LIVE_URL
          else
            test? ? test_url : live_url
          end
        end

        def commit(action, parameters)

          response = parse(ssl_post(url(action), parameters.to_json, { "Content-Type" => "application/json", "Accept" => "application/json" }))

          Response.new(
            returned_state_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            test: test?
          )
        end

        def returned_state_from(response)
          if response["transactionResponse"] && response["transactionResponse"]["state"]
            if response["code"] == "SUCCESS" && response["transactionResponse"]["state"] != "DECLINED" && response["transactionResponse"]["state"] != "REJECTED"
              { type: "success", code: response["transactionResponse"]["responseCode"], state: response["transactionResponse"]["state"] }
            else
              { type: "error", code: response["transactionResponse"]["responseCode"], state: response["transactionResponse"]["state"] }
            end
          else
            { type: response["code"], code: response["code"], state: response["code"] }
          end
        end

        def message_from(response)
          if response["transactionResponse"] && response["transactionResponse"]["responseMessage"]
            response["transactionResponse"]["responseMessage"]
          else
            response["error"]
          end
        end

        def authorization_from(response)
        end

        def test?
          ::Rails.env.test?
        end
    end
  end
end