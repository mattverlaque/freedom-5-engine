#
# Override the AM class to make the purchase method
# accept a creditcard *or* a customer token as the second
# parameter, like the other stored-value gateways.
#
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class StripeGateway < Gateway

      # To create a charge on a card, token, or customer call
      #
      #   purchase(money, card_or_token, { ... })
      #
      def purchase_with_customer(money, card_or_token, options = {})
        if card_or_token.to_s =~ /^cus_/
          options[:customer] ||= card_or_token
          card_or_token = nil
        end

        purchase_without_customer(money, card_or_token, options)
      end

      alias_method_chain :purchase, :customer

    end

    # This overrides the breaking API change here: https://github.com/activemerchant/active_merchant/commit/1f0a087e64604f66b33f7be92a105913cb9e5d64,
    def update(customer_id, creditcard, options = {})
      options = options.merge(:customer => customer_id, :set_default => true)
      store(creditcard, options)
    end
  end
end
