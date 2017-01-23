module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CreditCard
      # Returns or sets the zip code.
      #
      # @return [String]
      attr_accessor :zip

      def name=(full_name)
        self.first_name, self.last_name = full_name.strip.split(" ", 2)
      end

    end
  end
end
