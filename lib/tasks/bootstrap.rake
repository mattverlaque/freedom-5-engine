require 'rails/generators'

namespace :saas do
  desc 'Load an initial set of data'
  task :bootstrap => :environment do
    if SubscriptionPlan.count == 0
      plans = [
        { 'name' => 'Free', 'amount' => 0, 'user_limit' => 2 },
        { 'name' => 'Basic', 'amount' => 10, 'user_limit' => 5 },
        { 'name' => 'Premium', 'amount' => 30, 'user_limit' => nil }
      ].collect do |plan|
        SubscriptionPlan.create(plan)
      end
    end
    
    login, password = SecureRandom.hex(8).scan(/.{8}/)
    SaasAdmin.create(:email => "#{login}@example.com", :password => password, :password_confirmation => password)

    puts <<-EOF

      All done!
      
      You can login to the admin at
      http://#{Saas::Config.base_domain}/saas_admin with the
      email #{login}@example.com and password #{password}

    EOF
    
    if Rails.version < "4.1"
      puts <<-EOF
        If you haven't changed the secret in config/initializers/secret_token.rb yet, you really should!
        Here's a new secret you can use:
        
        #{SecureRandom.hex(64)}
        
      EOF
    end
  end
end
