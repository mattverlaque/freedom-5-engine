require 'ostruct'

module Saas
  Config = OpenStruct.new

  module Base
    def self.included(base)
      base.class_eval do
        extend ClassMethods
      end
    end
  end

  module ClassMethods
    # The limits hash is used to add some methods to the class that you can
    # use to check whether the subscriber has the rights to do something.
    # The hash keys match the *_limit fields in the subscriptions and
    # subscription_plan tables, and the values are the methods that will be
    # called to see if that limit has been reached.  For example,
    #
    # { 'user_limit' => Proc.new {|a| a.users.count } }
    #
    # defines a single limit based on the user_limit attribute that would
    # call users.account on the instance of the model that is invoking this
    # method.  In other words, if you have this:
    #
    # class Account < ActiveRecord::Base
    #   has_subscription({ 'user_limit' => Proc.new {|a| a.users.count } })
    # end
    #
    # then you could call @account.reached_user_limit? to know whether to allow
    # the account to create another user.
    def has_subscription(limits = {})
      has_one :subscription, :dependent => :destroy, :as => :subscriber
      has_many :subscription_payments, :as => :subscriber

      accepts_nested_attributes_for :subscription

      validate :valid_plan?, on: :create
      validate :valid_subscription?, on: :create

      send(:include, InstanceMethods)

      attr_accessor :plan, :plan_start, :creditcard, :address, :affiliate

      after_commit :send_welcome_email, on: :create

      class_attribute :subscription_limits
      self.subscription_limits = limits

      # Create methods for each limit for checking the limit.
      # E.g., for a field user_limit, this will define reached_user_limit?
      limits.each do |name, meth|
        define_method("reached_#{name}?") do
          return false unless self.subscription
          # A nil value will always return false, or, in other words, nil == unlimited
          subscription.send(name) && subscription.send(name) <= meth.call(self)
        end
      end
    end
  end

  module InstanceMethods

    def home_url(path = nil)
      "http://#{ [(respond_to?(:full_domain) ? full_domain : Saas::Config.base_domain), path].compact.join("/") }"
    end

    # Does the account qualify for a particular subscription plan
    # based on the plan's limits
    def qualifies_for?(plan)
      self.class.subscription_limits.map do |name, meth|
        limit = plan.send(name)
        !limit || (meth.call(self) <= limit)
      end.all?
    end

    def needs_payment_info?
      if new_record?
        @plan && @plan.amount.to_f + @plan.setup_amount.to_f > 0 && (Saas::Config.require_payment_info_for_trials || !@plan.trial_period?)
      else
        self.subscription.needs_payment_info?
      end
    end

    def active?
      subscription.current?
    end

    protected

      def valid_plan?
        errors.add(:base, "Invalid plan selected.") unless @plan
      end

      def valid_subscription?
        return if errors.any? # Don't bother with a subscription if there are errors already
        self.build_subscription(:plan => @plan, :next_renewal_at => @plan_start, :creditcard => @creditcard, :address => @address, :affiliate => @affiliate)
        if !subscription.valid?
          errors.add(:base, "Error with payment: #{subscription.errors.full_messages.to_sentence}")
          return false
        end
      end

      def send_welcome_email
        SubscriptionNotifier.welcome(self).deliver_later
      end
  end
end

ActiveRecord::Base.send :include, Saas::Base
