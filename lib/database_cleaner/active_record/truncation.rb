require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'

#Load available connection adapters
%w(
  abstract_mysql_adapter postgresql_adapter sqlite3_adapter mysql2_adapter oracle_enhanced_adapter
).each do |known_adapter|
  begin
    require "active_record/connection_adapters/#{known_adapter}"
  rescue LoadError
  end
end

require 'database_cleaner/active_record/base'

module DatabaseCleaner
  module ActiveRecord
    module ConnectionAdapters
      module AbstractAdapter
        # used to be called views but that can clash with gems like schema_plus
        # this gem is not meant to be exposing such an extra interface any way
        def database_cleaner_view_cache
          @views ||= select_values("select table_name from information_schema.views where table_schema = '#{current_database}'") rescue []
        end

        def database_cleaner_table_cache
          # the adapters don't do caching (#130) but we make the assumption that the list stays the same in tests
          @database_cleaner_tables ||= database_tables
        end

        def database_tables
          tables
        end

        def truncate_table(table_name)
          raise NotImplementedError
        end

        def truncate_tables(tables)
          tables.each do |table_name|
            self.truncate_table(table_name)
          end
        end
      end

      module AbstractMysqlAdapter
        def truncate_table(table_name)
          execute("TRUNCATE TABLE #{quote_table_name(table_name)};")
        end

        def truncate_tables(tables)
          tables.each { |t| truncate_table(t) }
        end

        def pre_count_truncate_tables(tables)
          truncate_tables(tables.select { |table| has_been_used?(table) })
        end

        private

        def row_count(table)
          # Patch for MysqlAdapter with ActiveRecord 3.2.7 later
          # select_value("SELECT 1") #=> "1"
          select_value("SELECT EXISTS (SELECT 1 FROM #{quote_table_name(table)} LIMIT 1)").to_i
        end

        def auto_increment_value(table)
          select_value(<<-SQL).to_i
            SELECT auto_increment
            FROM information_schema.tables
            WHERE table_name = '#{table}'
            AND table_schema = database()
          SQL
        end

        # This method tells us if the given table has been inserted into since its
        # last truncation. Note that the table might have been populated, which
        # increased the auto-increment counter, but then cleaned again such that
        # it appears empty now.
        def has_been_used?(table)
          has_rows?(table) || auto_increment_value(table) > 1
        end

        def has_rows?(table)
          row_count(table) > 0
        end
      end

      module IBM_DBAdapter
        def truncate_table(table_name)
          execute("TRUNCATE #{quote_table_name(table_name)} IMMEDIATE")
        end
      end

      module SQLiteAdapter
        def delete_table(table_name)
          execute("DELETE FROM #{quote_table_name(table_name)};")
          if uses_sequence
            execute("DELETE FROM sqlite_sequence where name = '#{table_name}';")
          end
        end
        alias truncate_table delete_table

        def truncate_tables(tables)
          tables.each { |t| truncate_table(t) }
        end

        private

        # Returns a boolean indicating if the SQLite database is using the sqlite_sequence table.
        def uses_sequence
          select_value("SELECT name FROM sqlite_master WHERE type='table' AND name='sqlite_sequence';")
        end
      end

      module TruncateOrDelete
        def truncate_table(table_name)
          begin
            execute("TRUNCATE TABLE #{quote_table_name(table_name)};")
          rescue ::ActiveRecord::StatementInvalid
            execute("DELETE FROM #{quote_table_name(table_name)};")
          end
        end
      end

      module OracleAdapter
        def truncate_table(table_name)
          execute("TRUNCATE TABLE #{quote_table_name(table_name)}")
        end
      end

      module PostgreSQLAdapter
        def db_version
          @db_version ||= postgresql_version
        end

        def cascade
          @cascade ||= db_version >=  80200 ? 'CASCADE' : ''
        end

        def restart_identity
          @restart_identity ||= db_version >=  80400 ? 'RESTART IDENTITY' : ''
        end

        def database_tables
          tables_with_schema
        end

        def truncate_table(table_name)
          truncate_tables([table_name])
        end

        def truncate_tables(table_names)
          return if table_names.nil? || table_names.empty?
          execute("TRUNCATE TABLE #{table_names.map{|name| quote_table_name(name)}.join(', ')} #{restart_identity} #{cascade};")
        end

        def pre_count_truncate_tables(tables)
          truncate_tables(tables.select { |table| has_been_used?(table) })
        end

        def database_cleaner_table_cache
          # AR returns a list of tables without schema but then returns a
          # migrations table with the schema. There are other problems, too,
          # with using the base list. If a table exists in multiple schemas
          # within the search path, truncation without the schema name could
          # result in confusing, if not unexpected results.
          @database_cleaner_tables ||= tables_with_schema
        end

        private

        # Returns a boolean indicating if the given table has an auto-inc number higher than 0.
        # Note, this is different than an empty table since an table may populated, the index increased,
        # but then the table is cleaned.  In other words, this function tells us if the given table
        # was ever inserted into.
        def has_been_used?(table)
          return has_rows?(table) unless has_sequence?(table)

          cur_val = select_value("SELECT currval('#{table}_id_seq');").to_i rescue 0
          cur_val > 0
        end

        def has_sequence?(table)
          select_value("SELECT true FROM pg_class WHERE relname = '#{table}_id_seq';")
        end

        def has_rows?(table)
          select_value("SELECT true FROM #{table} LIMIT 1;")
        end

        def tables_with_schema
          rows = select_rows <<-_SQL
            SELECT schemaname || '.' || tablename
            FROM pg_tables
            WHERE
              tablename !~ '_prt_' AND
              #{DatabaseCleaner::ActiveRecord::Base.exclusion_condition('tablename')} AND
              schemaname = ANY (current_schemas(false))
          _SQL
          rows.collect { |result| result.first }
        end
      end
    end
  end
end

#Apply adapter decoraters where applicable (adapter should be loaded)
ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::AbstractAdapter }

if defined?(ActiveRecord::ConnectionAdapters::JdbcAdapter)
  if defined?(ActiveRecord::ConnectionAdapters::OracleJdbcConnection)
    ActiveRecord::ConnectionAdapters::JdbcAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::OracleAdapter }
  else
    ActiveRecord::ConnectionAdapters::JdbcAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::TruncateOrDelete }
  end
end

ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter } if defined?(ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter)
ActiveRecord::ConnectionAdapters::Mysql2Adapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter } if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter } if defined?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
ActiveRecord::ConnectionAdapters::SQLiteAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::SQLiteAdapter } if defined?(ActiveRecord::ConnectionAdapters::SQLiteAdapter)
ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::SQLiteAdapter } if defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter } if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
ActiveRecord::ConnectionAdapters::IBM_DBAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::IBM_DBAdapter } if defined?(ActiveRecord::ConnectionAdapters::IBM_DBAdapter)
ActiveRecord::ConnectionAdapters::SQLServerAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::TruncateOrDelete } if defined?(ActiveRecord::ConnectionAdapters::SQLServerAdapter)
ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval { include DatabaseCleaner::ActiveRecord::ConnectionAdapters::OracleAdapter } if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)

module DatabaseCleaner
  module ActiveRecord
    class Truncation < Base
      def initialize(opts={})
        if !opts.empty? && !(opts.keys - [:only, :except, :pre_count, :reset_ids, :cache_tables]).empty?
          raise ArgumentError, "The only valid options are :only, :except, :pre_count, :reset_ids or :cache_tables. You specified #{opts.keys.join(',')}."
        end
        if opts.has_key?(:only) && opts.has_key?(:except)
          raise ArgumentError, "You may only specify either :only or :except.  Doing both doesn't really make sense does it?"
        end

        @only = opts[:only]
        @tables_to_exclude = Array( (opts[:except] || []).dup ).flatten
        @tables_to_exclude += migration_storage_names
        @pre_count = opts[:pre_count]
        @reset_ids = opts[:reset_ids]
        @cache_tables = opts.has_key?(:cache_tables) ? !!opts[:cache_tables] : true
      end

      def clean
        connection = connection_class.connection
        connection.disable_referential_integrity do
          if pre_count? && connection.respond_to?(:pre_count_truncate_tables)
            connection.pre_count_truncate_tables(tables_to_truncate(connection))
          else
            connection.truncate_tables(tables_to_truncate(connection))
          end
        end
      end

      private

      def tables_to_truncate(connection)
        tables_in_db = cache_tables? ? connection.database_cleaner_table_cache : connection.database_tables
        to_reject = (@tables_to_exclude + connection.database_cleaner_view_cache)
        (@only || tables_in_db).reject do |table|
          if ( m = table.match(/([^.]+)$/) )
            to_reject.include?(m[1])
          else
            false
          end
        end
      end

      def migration_storage_names
        result = [DatabaseCleaner::ActiveRecord::Base.migration_table_name]
        result << ::ActiveRecord::Base.internal_metadata_table_name if ::ActiveRecord::VERSION::MAJOR >= 5
        result
      end

      def cache_tables?
        !!@cache_tables
      end

      def pre_count?
        @pre_count == true
      end
    end
  end
end
