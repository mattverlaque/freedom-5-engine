module Saas
  class Engine < Rails::Engine
    initializer 'saas.helper' do |app|
      ActionView::Base.send :include, SubscriptionDiscountHelper
    end
  end
end
