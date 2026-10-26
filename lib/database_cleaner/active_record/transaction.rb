module DatabaseCleaner
  module ActiveRecord
    class Transaction < Base
      def initialize(opts={})
        if !opts.empty? && !(opts.keys - [:lock_threads]).empty?
          raise ArgumentError, "The only valid option is :lock_threads. You specified #{opts.keys.join(',')}."
        end

        @lock_threads = opts.has_key?(:lock_threads) ? !!opts[:lock_threads] : true
      end

      def start
        if pin_connection?
          # Pin the connection the way Rails' transactional tests do, so it stays leased (and its
          # transaction visible) even when an executor wrap releases connections, and so other
          # threads share it instead of checking out one that can't see the uncommitted data.
          pool = connection_class.connection_pool
          pool.pin_connection!(@lock_threads)
          connection = pool.lease_connection
          # Rails 7.2-8.1 open the transaction in pin_connection!; later versions leave it to the caller.
          began_transaction = !connection.transaction_open?
          connection.begin_transaction(joinable: false, _lazy: false) if began_transaction
          pins << began_transaction
          return
        end

        connection = connection_class.connection

        # Hack to make sure that the connection is properly set up before cleaning
        connection.transaction {}

        connection.begin_transaction joinable: false
      end


      def clean
        if pin_connection?
          pool = connection_class.connection_pool
          until pins.empty?
            if pins.pop
              connection = pool.lease_connection
              connection.rollback_transaction if connection.transaction_open?
            end
            pool.unpin_connection!
          end
          pool.release_connection
          return
        end

        connection_class.connection_pool.connections.each do |connection|
          connection.lock.synchronize do
            next unless connection.open_transactions > 0
            connection.rollback_transaction
          end
        end

        connection_class.connection_pool.release_connection
      end

      private

      def pin_connection?
        ::ActiveRecord.version >= Gem::Version.new("7.2")
      end

      def pins
        @pins ||= []
      end
    end
  end
end
