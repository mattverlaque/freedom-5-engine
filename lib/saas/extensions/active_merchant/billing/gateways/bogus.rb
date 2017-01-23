module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # Bogus Gateway
    class BogusGateway < Gateway
      # Fake an update by calling store
      def update(identification, creditcard, options = {})
        store(creditcard, options)
      end
    end
  end
end
