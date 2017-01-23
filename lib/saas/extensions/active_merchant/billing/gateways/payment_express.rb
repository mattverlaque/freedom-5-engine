module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaymentExpressGateway < Gateway
      # Unsupported
      def unstore(identification, options = {})
        # no-op
      end
      
      # Unsupported.  Just create a new record and return it.
      def update(identification, creditcard, options = {})
        store(creditcard, options)
      end  
    end
  end
end