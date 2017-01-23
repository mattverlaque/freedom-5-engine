class CreateSaasTables < ActiveRecord::Migration
  def self.up
    create_table "subscription_affiliates", :force => true do |t|
      t.string   "name"
      t.decimal  "rate",       :precision => 6, :scale => 4, :default => 0.0
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "token"
    end

    add_index "subscription_affiliates", ["token"], :name => "index_subscription_affiliates_on_token"

    create_table "subscription_discounts", :force => true do |t|
      t.string   "name"
      t.string   "code"
      t.decimal  "amount",                 :precision => 6, :scale => 2, :default => 0.0
      t.boolean  "percent"
      t.date     "start_on"
      t.date     "end_on"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "apply_to_setup",                                       :default => true
      t.boolean  "apply_to_recurring",                                   :default => true
      t.integer  "trial_period_extension",                               :default => 0
    end

    create_table "subscription_payments", :force => true do |t|
      t.integer  "subscription_id"
      t.decimal  "amount",                    :precision => 10, :scale => 2, :default => 0.0
      t.string   "transaction_id"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "setup"
      t.boolean  "misc"
      t.integer  "subscription_affiliate_id"
      t.decimal  "affiliate_amount",          :precision => 6,  :scale => 2, :default => 0.0
      t.integer  "subscriber_id"
      t.string   "subscriber_type"
    end

    add_index "subscription_payments", ["subscriber_id", "subscriber_type"], :name => "index_payments_on_subscriber"
    add_index "subscription_payments", ["subscription_id"], :name => "index_subscription_payments_on_subscription_id"

    create_table "subscription_plans", :force => true do |t|
      t.string   "name"
      t.decimal  "amount",         :precision => 10, :scale => 2
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "renewal_period",                                :default => 1
      t.decimal  "setup_amount",   :precision => 10, :scale => 2
      t.integer  "trial_period",                                  :default => 1
      t.string   "trial_interval",                                :default => 'months'
      t.integer  "user_limit"
    end

    create_table "subscriptions", :force => true do |t|
      t.decimal  "amount",                    :precision => 10, :scale => 2
      t.datetime "next_renewal_at"
      t.string   "card_number"
      t.string   "card_expiration"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "state",                                                    :default => "trial"
      t.integer  "subscription_plan_id"
      t.integer  "subscriber_id"
      t.string   "subscriber_type"
      t.integer  "renewal_period",                                           :default => 1
      t.string   "billing_id"
      t.integer  "subscription_discount_id"
      t.integer  "subscription_affiliate_id"
      t.integer  "user_limit"
    end

    add_index "subscriptions", ["subscriber_id", "subscriber_type"], :name => "index_subscriptions_on_subscriber"
  end

  def self.down
    drop_table "subscription_affiliates"
    drop_table "subscription_discounts"
    drop_table "subscription_payments"
    drop_table "subscription_plans"
    drop_table "subscriptions"
  end
end
