module DatabaseCleaner
  module ActiveRecord
    module Rails3
      def start
        @fixture_connections = enlist_fixture_connections

        @fixture_connections.each do |connection|
          connection.increment_open_transactions
          connection.transaction_joinable = false
          connection.begin_db_transaction
        end
      end

      def clean
        @fixture_connections.each do |connection|
          if connection.open_transactions != 0
            connection.rollback_db_transaction
            connection.decrement_open_transactions
          end
        end
        @fixture_connections.clear
        ActiveRecord::Base.clear_active_connections!
      end

      def enlist_fixture_connections
        ActiveRecord::Base.connection_handler.connection_pools.values.map(&:connection)
      end
    end
  end
end

