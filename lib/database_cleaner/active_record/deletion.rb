require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'
require "database_cleaner/generic/truncation"
require 'database_cleaner/active_record/truncation'

module DatabaseCleaner
  module ActiveRecord
    module ConnectionAdapters
      module AbstractDeleteAdapter
        def delete_table(table_name)
          raise NotImplementedError
        end
      end

      module GenericDeleteAdapter
        def delete_table(table_name)
          execute("DELETE FROM #{quote_table_name(table_name)};")
        end
      end

      module OracleDeleteAdapter
        def delete_table(table_name)
          execute("DELETE FROM #{quote_table_name(table_name)}")
        end
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::AbstractDeleteAdapter }
ActiveRecord::ConnectionAdapters::JdbcAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::JdbcAdapter)
ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)
ActiveRecord::ConnectionAdapters::Mysql2Adapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
ActiveRecord::ConnectionAdapters::SQLiteAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::SQLiteAdapter)
ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
ActiveRecord::ConnectionAdapters::IBM_DBAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::IBM_DBAdapter)
ActiveRecord::ConnectionAdapters::SQLServerAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::GenericDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::SQLServerAdapter)
ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::OracleDeleteAdapter } if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)

module DatabaseCleaner
  module ActiveRecord
    module SelectiveTruncation
      def tables_to_truncate(connection)
        if information_schema_exists?(connection)
          (@only || tables_with_new_rows(connection)) - @tables_to_exclude
        else
          super
        end
      end

      def tables_with_new_rows(connection)
        stats = table_stats_query(connection)
        if stats != ''
          connection.select_values(stats)
        else
          []
        end
      end

      def table_stats_query(connection)
        @table_stats_query ||= build_table_stats_query(connection)
      ensure
        @table_stats_query = nil unless @cache_tables
      end

      def build_table_stats_query(connection)
        tables = connection.select_values(<<-SQL)
          SELECT table_name
          FROM information_schema.tables
          WHERE table_schema = database()
          AND #{DatabaseCleaner::ActiveRecord::Base.exclusion_condition('table_name')};
        SQL
        queries = tables.map do |table|
          "(SELECT #{connection.quote(table)} FROM #{connection.quote_table_name(table)} LIMIT 1)"
        end
        queries.join(' UNION ALL ')
      end

      def information_schema_exists? connection
        return false unless connection.is_a? ActiveRecord::ConnectionAdapters::Mysql2Adapter
        @information_schema_exists ||=
          begin
            connection.execute("SELECT 1 FROM information_schema.tables")
            true
          rescue
            false
          end
      end
    end

    class Deletion < Truncation
      if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
        include SelectiveTruncation
      end

      def clean
        connection = connection_class.connection
        connection.disable_referential_integrity do
          tables_to_truncate(connection).each do |table_name|
            connection.delete_table table_name
          end
        end
      end
    end
  end
end
