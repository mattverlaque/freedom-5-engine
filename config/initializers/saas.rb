begin
  config_file = Rails.root.join('config', 'saas.yml')
  YAML.load(ERB.new(File.read(config_file)).result)[Rails.env].each do |k, v|
    Saas::Config.send("#{k}=", v)
  end
  Rails.application.config.action_mailer.default_url_options = { :host => Saas::Config.base_domain }
rescue
  puts "Error with SaaS plugin: The config file #{config_file} is missing or badly formatted.  Please run 'rails generate saas' to generate one and generate the migrations.\n\n"
end
