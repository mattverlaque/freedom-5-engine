class SubscriptionDiscount < ActiveRecord::Base
  include Comparable
  class ComparableError < StandardError; end

  validates_numericality_of :amount
  validates_presence_of :code, :name

  before_save :check_percentage

  attr_accessor :calculated_amount

  def available?
    return false if start_on && start_on > Time.now.utc.to_date
    return false if end_on && end_on < Time.now.utc.to_date
    true
  end

  def calculate(subtotal)
    return 0 unless subtotal.to_i > 0
    return 0 unless available?
    self.calculated_amount = if percent
      (amount * subtotal).round(2)
    else
      amount > subtotal ? subtotal : amount
    end
  end

  def <=>(other)
    return 1 if other.nil?
    raise ComparableError, "Can't compare discounts that are calculated differently" if percent != other.percent
    amount <=> other.amount
  end

  protected

    def check_percentage
      if amount > 1 and percent
        self.amount = amount / 100
      end
    end

end
