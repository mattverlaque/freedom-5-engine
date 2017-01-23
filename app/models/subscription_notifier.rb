class SubscriptionNotifier < ActionMailer::Base
  include ActionView::Helpers::NumberHelper

  default :from => Saas::Config.from_email

  def setup_environment(obj)
    if obj.is_a?(SubscriptionPayment)
      @subscription = obj.subscription
      @amount = obj.amount
    elsif obj.is_a?(Subscription)
      @subscription = obj
    end
    @subscriber = @subscription.subscriber
  end

  def welcome(account)
    @subscriber = account
    mail(:to => @subscriber.email, :subject => "Welcome to #{Saas::Config.app_name}!")
  end

  def trial_expiring(subscription)
    setup_environment(subscription)
    mail(:to => @subscriber.email, :subject => 'Trial period expiring')
  end

  def charge_receipt(subscription_payment)
    setup_environment(subscription_payment)
    mail(:to => @subscriber.email, :subject => "Your #{Saas::Config.app_name} invoice")
  end

  def setup_receipt(subscription_payment)
    setup_environment(subscription_payment)
    mail(:to => @subscriber.email, :subject => "Your #{Saas::Config.app_name} invoice")
  end

  def misc_receipt(subscription_payment)
    setup_environment(subscription_payment)
    mail(:to => @subscriber.email, :subject => "Your #{Saas::Config.app_name} invoice")
  end

  def charge_failure(subscription)
    setup_environment(subscription)
    mail(:to => @subscriber.email, :subject => "Your #{Saas::Config.app_name} renewal failed",
      :bcc => Saas::Config.from_email)
  end

  def plan_changed(subscription)
    setup_environment(subscription)
    mail(:to => @subscriber.email, :subject => "Your #{Saas::Config.app_name} plan has been changed")
  end
end
