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
        if connection_class.legacy_connection_handling
          writing_handler = connection_class.connection_handlers[connection_class.writing_role]

          connection_class.connection_handlers.values.each do |handler|
            if handler != writing_handler
              handler.connection_pool_names.each do |name|
                writing_pool_manager = writing_handler.send(:owner_to_pool_manager)[name]
                return unless writing_pool_manager

                pool_manager = handler.send(:owner_to_pool_manager)[name]
                pool_manager.shard_names.each do |shard_name|
                  writing_pool_config = writing_pool_manager.get_pool_config(nil, shard_name)
                  pool_manager.set_pool_config(nil, shard_name, writing_pool_config)
                end
              end
            end
          end
        else
          handler = connection_class.connection_handler

          handler.connection_pool_names.each do |name|
            pool_manager = handler.send(:owner_to_pool_manager)[name]
            pool_manager.shard_names.each do |shard_name|
              writing_pool_config = pool_manager.get_pool_config(connection_class.writing_role, shard_name)
              pool_manager.role_names.each do |role|
                next unless pool_manager.get_pool_config(role, shard_name)
                pool_manager.set_pool_config(role, shard_name, writing_pool_config)
              end
            end
          end
        end
      end
    end
  end
end
