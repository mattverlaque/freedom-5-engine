module Saas
  module Generators
    class SaasGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      namespace "saas"

      def self.source_root
        @source_root ||= File.join(File.dirname(__FILE__), 'templates')
      end

      def self.next_migration_number(dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def create_migration_file
        migration_template 'migration.rb', 'db/migrate/create_saas_tables.rb' unless Subscription.table_exists?
      end

      def copy_config_file
        template 'saas.yml', File.join('config', 'saas.yml')
      end

    end

  end
end
