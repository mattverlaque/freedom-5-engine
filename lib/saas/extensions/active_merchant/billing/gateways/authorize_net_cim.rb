require 'digest/sha1'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AuthorizeNetCimGateway < Gateway
      
      # The following methods are for compatibility with 
      # other stored-value gateways

      # Create a payment profile
      def store(creditcard, options = {})
        profile = {
          :payment_profiles => {
            :payment => { :credit_card => creditcard }
          }
        }
        profile[:payment_profiles][:bill_to] = options[:billing_address] if options[:billing_address]
        profile[:ship_to_list] = options[:shipping_address] if options[:shipping_address]

        # CIM actually does require a unique ID to be passed in, 
        # either merchant_customer_id or email, so generate it, if necessary
        if options[:billing_id]
          profile[:merchant_customer_id] = options[:billing_id]
        elsif options[:email]
          profile[:email] = options[:email]
        else
          profile[:merchant_customer_id] = Digest::SHA1.hexdigest("#{creditcard.number}#{Time.now.to_i}").first(20)
        end

        create_customer_profile(:profile => profile)
      end

      # Update an existing payment profile
      def update(billing_id, creditcard, options = {})
        if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
          update_customer_payment_profile(
            :customer_profile_id => billing_id,
            :payment_profile => {
              :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'],
              :payment => {
                :credit_card => creditcard
              }
            }.merge(options[:billing_address] ? {:bill_to => options[:billing_address]} : {})
          )
        else
          response
        end
      end

      # Run an auth and capture transaction against the stored CC
      def purchase(money, billing_id)
        if (response = get_customer_profile(:customer_profile_id => billing_id)).success?
          create_customer_profile_transaction(:transaction => { :customer_profile_id => billing_id, :customer_payment_profile_id => response.params['profile']['payment_profiles']['customer_payment_profile_id'], :type => :auth_capture, :amount => amount(money) })
        else
          response
        end
      end

      # Destroy a customer profile
      def unstore(billing_id)
        delete_customer_profile(:customer_profile_id => billing_id)
      end
    end
  end
end
