class Subscription < ActiveRecord::Base
  belongs_to :subscriber, :polymorphic => true
  belongs_to :subscription_plan
  has_many :subscription_payments
  belongs_to :discount, :class_name => 'SubscriptionDiscount', :foreign_key => 'subscription_discount_id'
  belongs_to :affiliate, :class_name => 'SubscriptionAffiliate', :foreign_key => 'subscription_affiliate_id'

  before_create :set_renewal_at
  before_update :apply_discount
  before_destroy :destroy_gateway_record

  attr_accessor :creditcard, :address
  attr_reader :response

  # renewal_period is the number of months to bill at a time
  # default is 1
  validates_numericality_of :renewal_period, :only_integer => true, :greater_than => 0
  validates_numericality_of :amount, :greater_than_or_equal_to => 0
  validate :card_storage, :on => :create
  validate :within_limits, :on => :update

  #
  # Changes the subscription plan, and assigns various properties,
  # such as limits, etc., to the subscription from the assigned
  # plan.
  #
  # When adding new limits that are specified in SubscriptionPlan,
  # if you name them like "some_quantity_limit", they will automatically
  # be used by this method.
  #
  # Otherwise, you'll need to manually add the assignment to this method.
  #
  def plan=(plan)
    if plan.amount > 0
      # Discount the plan with the existing discount (if any)
      # if the plan doesn't already have a better discount
      plan.discount = discount if discount && discount > plan.discount
      # If the assigned plan has a better discount, though, then
      # assign the discount to the subscription so it will stick
      # through future plan changes
      self.discount = plan.discount if plan.discount && plan.discount > discount
      self.state = 'active' unless plan.trial_period?
    else
      # Free account from the get-go?  No point in having a trial
      self.state = 'active' if new_record?
    end

    #
    # Find any attributes that exist in both the Subscription and SubscriptionPlan
    # and that match the pattern of "something_limit"
    #
    limits = self.attributes.keys.select { |k| k =~ /^.+_limit$/ } &
             plan.attributes.keys.select { |k| k =~ /^.+_limit$/ }

    (limits + [:amount, :renewal_period]).each do |f|
      self.send("#{f}=", plan.send(f))
    end

    self.subscription_plan = plan
  end

  # The plan_id and plan_id= methods are convenience methods for the
  # administration interface.
  def plan_id
    subscription_plan_id
  end

  def plan_id=(a_plan_id)
    self.plan = SubscriptionPlan.find(a_plan_id) if a_plan_id.to_i != subscription_plan_id
  end

  def inactive?
    state == 'inactive'
  end

  def trial_days
    (self.next_renewal_at.to_i - Time.now.to_i) / 86400
  end

  def amount_in_pennies
    (amount * 100).to_i
  end

  def store_card(creditcard, gw_options = {})
    @response = if billing_id.blank?
      gateway.store(creditcard, gw_options)
    else
      if gateway.display_name == 'Stripe'
        customer_id= billing_id.split('|').first
        gw_options = gw_options.merge(customer: customer_id, set_default: true)
        gateway.store(creditcard, gw_options)
      else
        gateway.update(billing_id, creditcard, gw_options)
      end
    end

    if @response.success?
      if gateway.display_name == 'Stripe'
        default_card = @response.params
        default_card = default_card['sources']['data'][0] if default_card['sources']
        self.card_number = "XXXX-XXXX-XXXX-#{default_card['last4']}"
        self.card_expiration = '%02d-%d' % [default_card['exp_month'], default_card['exp_year']]
        self.billing_id = @response.params['id'] if self.billing_id.blank? && @response.params
      else
        self.card_number = creditcard.display_number
        self.card_expiration = "%02d-%d" % [creditcard.expiry_date.month, creditcard.expiry_date.year]
        self.billing_id = @response.token if self.billing_id.blank?
      end
      set_billing
    else
      errors.add(:base, @response.message)
      false
    end
  end

  # Charge the card on file the amount stored for the subscription
  # record.  This is called by the daily_mailer script for each
  # subscription that is due to be charged.  A SubscriptionPayment
  # record is created, and the subscription's next renewal date is
  # set forward when the charge is successful.
  def charge
    if amount == 0 || (@response = gateway.purchase(amount_in_pennies, billing_id)).success?
      update_attributes(:next_renewal_at => self.next_renewal_at.advance(:months => self.renewal_period), :state => 'active')
      subscription_payments.create(:subscriber => subscriber, :amount => amount, :transaction_id => @response.authorization) unless amount == 0
      true
    else
      errors.add(:base, @response.message)
      false
    end
  end

  # Charge the card on file any amount you want.  Pass in a dollar
  # amount (1.00 to charge $1).  A SubscriptionPayment record will
  # be created, but the subscription itself is not modified.
  def misc_charge(amount)
    if amount == 0 || (@response = gateway.purchase((amount.to_f * 100).to_i, billing_id)).success?
      subscription_payments.create(:subscriber => subscriber, :amount => amount, :transaction_id => @response.authorization, :misc => true)
      true
    else
      errors.add(:base, @response.message)
      false
    end
  end

  def needs_payment_info?
    amount > 0 && card_number.blank?
  end

  def self.find_expiring_trials(renew_at = 7.days.from_now)
    includes(:subscriber).where({ :state => 'trial', :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) })
  end

  def self.find_due_trials(renew_at = Time.now)
    includes(:subscriber).where({ :state => 'trial', :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) }).select {|s| !s.card_number.blank? }
  end

  def self.find_due(renew_at = Time.now)
    includes(:subscriber).where({ :state => 'active', :next_renewal_at => (renew_at.beginning_of_day .. renew_at.end_of_day) })
  end

  def current?
    next_renewal_at >= Time.now
  end

  def to_s
    "#{card_number} - #{card_expiration}"
  end

  protected

    def set_billing
      if new_record?
        if !next_renewal_at? || next_renewal_at < 1.day.from_now.at_midnight
          if subscription_plan.trial_period?
            self.next_renewal_at = Time.now.advance(subscription_plan.trial_interval.to_sym => subscription_plan.trial_period)
          else
            charge_amount = subscription_plan.setup_amount? ? subscription_plan.setup_amount : amount
            if (@response = gateway.purchase(charge_amount * 100, billing_id)).success?
              subscription_payments.build(:subscriber => subscriber, :amount => charge_amount, :transaction_id => @response.authorization, :setup => subscription_plan.setup_amount?)
              self.state = 'active'
              self.next_renewal_at = Time.now.advance(:months => renewal_period)
            else
              errors.add(:base, @response.message)
              return false
            end
          end
        end
      else
        if !next_renewal_at? || next_renewal_at < 1.day.from_now.at_midnight
          if (@response = gateway.purchase(amount_in_pennies, billing_id)).success?
            subscription_payments.build(:subscriber => subscriber, :amount => amount, :transaction_id => @response.authorization)
            self.state = 'active'
            self.next_renewal_at = Time.now.advance(:months => renewal_period)
          else
            errors.add(:base, @response.message)
            return false
          end
        else
          self.state = 'active'
        end
        self.save
      end

      true
    end

    def set_renewal_at
      return if subscription_plan.nil? || next_renewal_at
      if subscription_plan.trial_period?
        self.next_renewal_at = Time.now.advance(subscription_plan.trial_interval.to_sym => subscription_plan.trial_period)
      else
        self.next_renewal_at = Time.now
      end
    end

    # If the discount is changed, set the amount to the discounted
    # plan amount with the new discount.
    def apply_discount
      if subscription_discount_id_changed?
        subscription_plan.discount = discount
        self.amount = subscription_plan.amount
      end
    end

    def gateway
      @gateway ||= ActiveMerchant::Billing::Base.gateway(Saas::Config.gateway).new(Saas::Config.credentials['gateway'])
    end

    def destroy_gateway_record
      return if billing_id.blank?
      gateway.unstore(billing_id)
      clear_billing_info
    end

    def clear_billing_info
      self.card_number = nil
      self.card_expiration = nil
      self.billing_id = nil
    end

    def card_storage
      self.store_card(@creditcard, :billing_address => @address.to_activemerchant) if @creditcard && @address && card_number.blank?
    end

    def within_limits
      return unless subscription_plan_id_changed?
      subscriber.class.subscription_limits.each do |limit, rule|
        unless (cap = subscription_plan.send(limit)).nil? || rule.call(subscriber) <= cap
          errors.add(:base, "#{limit.to_s.humanize} for new plan would be exceeded.")
        end
      end

    end
end
