# README

Welcome to the SaaS Kit Gem
===========================

The SaaS Rails Kit gets your new software-as-a-service site off to a running start by providing you a well-tested and proven recurring billing system with credit card payments.

You also get a framework for building membership-based applications, including account signups/upgrades/downgrades, tiered pricing levels with customizable limits (e.g, # of users, # of projects, etc.), multi-tenant data security in a single database, and more.

## Getting Started with An Existing Application

After updating your Gemfile and bundling this gem, run the
following commands to get started:

    rake generate saas

    rake db:migrate saas:bootstrap

This will update your database, load some sample data, and create
a config file for you in config/saas.yml (which you should
review).

Once that's done, you'll need to add the has_subscription call
to the model that will have the has_one :subscription relationship
(see the Account model in the sample app).  See the controllers
(including ApplicationController) for additional code you may
want to pull into your existing application.

## Supported Gateways

Off the shelf SaaSKit supports Authorize.net CIM, Braintree, Payment Express, Stripe, and TrustCommerce, all via ActiveMerchant. But more can be added with little effort by leveraging [ActiveMerchant](https://github.com/activemerchant/active_merchant)

**No local credit card storage.** All credit card information is stored with the payment gateway, so you don’t have to worry about the PCI implications of storing credit card numbers.

### Stripe
This kit supports [Stripe] (https://stripe.com/) via both their PCI compliant gateway, and secure JavaScript API. In both cases, you need to configure the gateway and credentials by setting “stripe” as the gateway and your secret key as the “login” in /config/saas.yml in your project.
Optionally, you may set the stripe_publishable_key value, which will take advantage of the JavaScript API (leave blank to use just the gateway). This method will use the same credit card form, but instead of posting the credit card info to your servers (requiring you to pass a higher-level PCI compliance standard), it will post the credit card info directly to Stripe servers. The Kit will then get a token that it can use to bill the user's credit card. In this manner, your user's credit card info never touches your server. When using the javascript method, the credit card form will be disabled by default to prevent submitting the user from submitting sensitive information to your server when the user does not have a JavaScript capable browser. The form is then enabled by JavaScript, and the payment information will be submitted directly to Stripe.

## FAQ

### How to set up subscriptions in your application?

Saaskit is really simple to set up in your project, you can add subscription functionality to a model in your application, for instance a Company model, by adding `has_subscription` to the code:

    class Company < ActiveRecord::Base
      has_subscription({ 'user_limit' => Proc.new {|a| a.users.count } })
    end

This will make it possible to use `company.reached_user_limit?` to validate the constraint and you'll be able to build more functionality depending of this constraint.

The Subscription model has a polymorphic relationship to a “Subscriber”, in this case Company model.  This allows you to set up as many subscription flows as your bussiness needs.

### How to customize subscription plans limits?

Saaskit provides the SubscriptionPlan model, where you could manage and customize the plans that you need for your business.

To add limits to your plan, you have to add a new column to your subscription_plans table. In a migration file:

  > add_column :subscription_plans, :user_limit, :integer

  > add_column :subscription_plans, :video_limit, :integer

Then you specify the limits in your parent model

    class Company < ActiveRecord::Base
      has_subscription 'video_limit' => Proc.new {|company| company.videos.count,
        'user_limit' => Proc.new {|company| company.users.count }
    end
            ​
This will make it possible to use company.reached_video_limit? or company.reached_user_limit? to validate this constraint and add functionality depending of these limits.

### How to extend saas-kit models?

Let's say you want to add custom validation to the SubscriptionPlan model.

You can reopen the class

    SubscriptioPlan.class_eval do
      validate :custom_validation

      def custom_validation
        if name.length < 3
          errors.add(:name, “Name is to short”)
        end
      end
    end

After reopen the class, you have to require it in your code so that it is available to the rails app. Some ways to do this, are as follows:

- Create an initializers with a `require 'lib/saas_extension.rb` line
- Require the file directly in your `config/application.rb`:

    config.after_initialize do
      require "#{Rails.root.join('app/decorators/subscription_plan_decorator.rb')}"
      # you can also require all the monkey patch at once like this
      # Dir[Rails.root.join("lib/saas_extentions/**/*.rb")].each { |f| require f }
    end

### What are SubscriptionDiscounts and how do they work?

You can create and assign discounts for subscriptions through the console, it could be a percentage or an amount, and to assign them through the app it will be like this ``http://yourdomain.com/signup/d/<discount_code>``.

### What are SubscriptionAffiliates and how do they work?

You can have affiliates to your app, the creation of those are from the console and keeps track of the affiliates who are paid for sending traffic to your site.  The token is used for constructing affiliate URLs, like http://your.domain.com/signup?ref=foo.  The rate is the percentage of each subscription payment that the affiliate should receive. For example, a $99 monthly subscription linked to an affiliate with a rate of 0.10 will earn the affiliate $9 per month.

You can have access to the fees you have to pay for a subscription using the method fees for instances of SubscriptionAffiliate, like this:

``subscription.affiliate.fees``

This will calculate the fees for the previous month.

If you want to change the parameter in the URL take a look in the application_controller file in the sample app and look for :ref, ref is the default name for the param but you can change it for the name you like and that’s all, now you can use your custom name.

### How periodic billing works?

Make sure you set up a cron job to run 'rake saas:run_billing' on a daily basis. This script does the charging for account renewals and sends notices of expiring trials.

If you want to customize the billing charge, you have to check out the **billing.rake** file. For instance, if you want to change your billing process to accept credits instead of charging directly to the credit card, you can add a block before **# Charge due subscriptions** block and add the functionality to do it.

### Does SaaSKit works with subdomain-based accounts?

Yes it does, you can build your app to accept subdomains or any other way that will let you distinguish between accounts, when the user is in the signup process will be asked to set it, if you want you can let the user to change this identificator but this is something that you have to make on your own, they will also be able to host it on their own domains.

## Contents (Highlights)

> app/

>> models/

>>> subscription.rb

Here's where the magic happens: card storage, billing, plan changes, etc.

The store_card method is used to authorize and store the
credit card info with the gateway. If the account is still in
the trial period, or is otherwise still current (been charged
within the last month), the card will just be stored, and the
next renewal date will be unchanged. Otherwise, the card will
be charged for the amount that's currently due, and the next
renewal date will be set to a month in the future.

The charge method is used by the billing rake task to bill
for the subscriptions on the renewal date.  This is where
you would make changes if you wanted to implement metered
billing.

> views/

>> subscription_notifier/


All the content for emails sent to account owners is here.


> lib/

>> extensions/


Extensions to ActiveMerchant


> saas/saas.rb

Class and instance methods related to subscriptions

**Here are some of the files in the sample app that you'll need to check out:**

> app/
>> controllers/
  >>> users_controller.rb

In this file you can find an example of how you can use limits in your application. Notice the before filter to enforce the limit, and the call to inherit_resources to pull in generic RESTful methods. Also notice the begin_of_association_chain method, which is used to scope all the finds to the current account (the current_account method is defined in lib/subscription_system). Use this pattern throughout your application to make sure users only see the data associated with their account.

> models/
  >> account.rb

Near the top of the file you'll notice call to has_subscription, which is loads the saas gem and sets up the various limits you'll be checking for plan eligibility and for being able to do various things in your app. For example, the user_limit entry in the hash checks the count of associated users, and is used to create the reached_user_limit? convenience method in the plugin.  Read the comments there for info on setting up tiered plan levels for your app.

  >> user.rb

Basic User model with some of Devise's functionality overridden to make the login scoped by account (so you can have one user with the same email address belonging to multiple accounts).

> views/
  >> accounts/

Views for updating billing, creating a new account, etc. are here

  >> content/

Homepage content (splash page) and other content, like an about page, privacy policy, etc. go here.

> config/
  >> saas.yml

Some settings for the application, fairly self-explanatory.  This is generated by the bootstrap task or the generator.


## Testing

If you'd like to run the included test suite, run 'rake spec' in the sample app.


## Updating to Rails 5

**If you want to update your application to Rails 5, you need to:**

* Update Ruby to 2.2.2 or newer

* Update saas-kit gem version in your Gemfile to '3.2.1' or newer and then bundle
  > gem 'saas-kit', '~> 3.2.1'

* Update your Rails version in your Gemfile to rails 5 or newer and then bundle
  > gem 'rails', '~> 5.0.0', '>= 5.0.0.1'

* Run rake rails:update

* If RailsAdmin is used as the admin engine, you need to specify github as the gem source and then bundle
  > gem 'rails_admin', github: 'sferik/rails_admin'
  > gem 'remotipart', github: 'mshibuya/remotipart'


**If you already have an existing application with Rails 5 and want to use saas-kit, you need to:**

* Update saas-kit gem version in your Gemfile to '3.2.1' or newer and then bundle
  > gem 'saas-kit', '~> 3.2.1'

* If RailsAdmin is used as the admin engine, you need to specify github as the gem source and then bundle
  > gem 'rails_admin', github: 'sferik/rails_admin'
  > gem 'remotipart', github: 'mshibuya/remotipart'


**If you are building a Rails application from scratch, we recommend using the provided sample app as guidance.**
