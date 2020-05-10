require 'active_record'
require 'database_cleaner/active_record/truncation'

module DatabaseCleaner
  module ActiveRecord
    class Deletion < Truncation
      def clean
        connection = connection_class.connection
        connection.disable_referential_integrity do
          tables_to_truncate(connection).each do |table_name|
            delete_table connection, table_name
          end
        end
      end

      private

      def delete_table connection, table_name
        connection.execute("DELETE FROM #{connection.quote_table_name(table_name)}")
      end

      def tables_to_truncate(connection)
        if information_schema_exists?(connection)
          @except += connection.database_cleaner_view_cache + migration_storage_names
          (@only.any? ? @only : tables_with_new_rows(connection)) - @except
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
        return false unless connection.is_a? ::ActiveRecord::ConnectionAdapters::Mysql2Adapter
        @information_schema_exists ||=
          begin
            connection.execute("SELECT 1 FROM information_schema.tables")
            true
          rescue
            false
          end
      end
    end
  end
end
