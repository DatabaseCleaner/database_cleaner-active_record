module DatabaseCleaner
  module ActiveRecord
    module Rails5
      def start
        @fixture_connections = enlist_fixture_connections
        @fixture_connections.each do |connection|
          connection.begin_transaction joinable: false
          connection.pool.lock_thread = true
        end

        # When connections are established in the future, begin a transaction too
        @connection_subscriber = ActiveSupport::Notifications.subscribe("!connection.active_record") do |_, _, _, _, payload|
          spec_name = payload[:spec_name] if payload.key?(:spec_name)

          if spec_name
            begin
              connection = connection_class.connection_handler.retrieve_connection(spec_name)
            rescue ConnectionNotEstablished
              connection = nil
            end

            if connection && !@fixture_connections.include?(connection)
              connection.begin_transaction joinable: false
              connection.pool.lock_thread = true
              @fixture_connections << connection
            end
          end
        end
      end

      def clean
        if @connection_subscriber
          ActiveSupport::Notifications.unsubscribe(@connection_subscriber)
          @connection_subscriber = nil
        end

        return unless @fixture_connections

        @fixture_connections.each do |connection|
          connection.rollback_transaction if connection.transaction_open?
          connection.pool.lock_thread = false
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
