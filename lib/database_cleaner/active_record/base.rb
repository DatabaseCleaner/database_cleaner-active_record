require 'active_record'
require 'database_cleaner/strategy'
require 'erb'
require 'yaml'

module DatabaseCleaner
  module ActiveRecord
    def self.config_file_location=(path)
      @config_file_location = path
    end

    def self.config_file_location
      @config_file_location ||= "#{Dir.pwd}/config/database.yml"
    end

    class Base < DatabaseCleaner::Strategy
      def self.migration_table_name
        ::ActiveRecord::SchemaMigration.table_name
      end

      def self.exclusion_condition(column_name)
        <<~SQL
          #{column_name} <> '#{DatabaseCleaner::ActiveRecord::Base.migration_table_name}'
            AND #{column_name} <> '#{::ActiveRecord::Base.internal_metadata_table_name}'
        SQL
      end

      def db=(*)
        super
        load_config
      end

      attr_accessor :connection_hash

      def connection_class
        @connection_class ||= if db && !db.is_a?(Symbol)
                                db
                              elsif connection_hash
                                (lookup_from_connection_pool rescue nil) || establish_connection
                              else
                                ::ActiveRecord::Base
                              end
      end

      private

      def load_config
        if self.db != :default && self.db.is_a?(Symbol) && File.file?(DatabaseCleaner::ActiveRecord.config_file_location)
          connection_details = YAML::load(ERB.new(IO.read(DatabaseCleaner::ActiveRecord.config_file_location)).result)
          @connection_hash   = valid_config(connection_details)[self.db.to_s]
        end
      end

      def valid_config(connection_file)
        if !::ActiveRecord::Base.configurations.nil? && !::ActiveRecord::Base.configurations.empty?
          if connection_file != ::ActiveRecord::Base.configurations
            return ::ActiveRecord::Base.configurations
          end
        end
        connection_file
      end

      def lookup_from_connection_pool
        if ::ActiveRecord::Base.respond_to?(:descendants)
          database_name = connection_hash["database"] || connection_hash[:database]
          models        = ::ActiveRecord::Base.descendants
          models.select(&:connection_pool).detect { |m| m.connection_pool.spec.config[:database] == database_name }
        end
      end

      def establish_connection
        ::ActiveRecord::Base.establish_connection(connection_hash)
        ::ActiveRecord::Base
      end
    end
  end
end
