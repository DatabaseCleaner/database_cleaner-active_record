module DatabaseCleaner
  module ActiveRecord
    module Rails6
      def start
        # Begin transactions for connections already established
        @fixture_connections = enlist_fixture_connections
        @fixture_connections.each do |connection|
          connection.begin_transaction joinable: false, _lazy: false
          connection.pool.lock_thread = true if lock_threads
        end

        # When connections are established in the future, begin a transaction too
        @connection_subscriber = ActiveSupport::Notifications.subscribe("!connection.active_record") do |_, _, _, _, payload|
          spec_name = payload[:spec_name] if payload.key?(:spec_name)
          shard = payload[:shard] if payload.key?(:shard)
          setup_shared_connection_pool

          if spec_name
            begin
              connection = connection_class.connection_handler.retrieve_connection(spec_name, shard: shard)
            rescue ConnectionNotEstablished
              connection = nil
            end

            if connection && !@fixture_connections.include?(connection)
              connection.begin_transaction joinable: false, _lazy: false
              connection.pool.lock_thread = true if lock_threads
              @fixture_connections << connection
            end
          end
        end
      end

      def clean
        return unless @fixture_connections

        if @connection_subscriber
          ActiveSupport::Notifications.unsubscribe(@connection_subscriber)
          @connection_subscriber = nil
        end

        @fixture_connections.each do |connection|
          connection.rollback_transaction if connection.transaction_open?
          connection.pool.lock_thread = false
        end
        @fixture_connections.clear

        connection_class.clear_active_connections!
      end

      def enlist_fixture_connections
        setup_shared_connection_pool

        connection_class.connection_handler.connection_pool_list.map(&:connection)
      end

      private

      # Shares the writing connection pool with connections on
      # other handlers.
      #
      # In an application with a primary and replica the test fixtures
      # need to share a connection pool so that the reading connection
      # can see data in the open transaction on the writing connection.
      def setup_shared_connection_pool
        writing_handler = connection_class.connection_handlers[ActiveRecord::Base.writing_role]

        connection_class.connection_handlers.values.each do |handler|
          if handler != writing_handler
            handler.connection_pool_list.each do |pool|
              name = pool.spec.name
              writing_connection = writing_handler.retrieve_connection_pool(name)
              return unless writing_connection
              handler.send(:owner_to_pool)[name] = writing_connection
            end
          end
        end
      end
    end
  end
end
