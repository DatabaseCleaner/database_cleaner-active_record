module DatabaseCleaner
  module ActiveRecord
    module Rails4
      def start
        @fixture_connections = enlist_fixture_connections
        @fixture_connections.each do |connection|
          connection.begin_transaction joinable: false
        end
      end

      def clean
        @fixture_connections.each do |connection|
          connection.rollback_transaction if connection.transaction_open?
        end
        @fixture_connections.clear
        connection_class.clear_active_connections!
      end

      def enlist_fixture_connections
        connection_class.connection_handler.connection_pool_list.map(&:connection)
      end
    end
  end
end
