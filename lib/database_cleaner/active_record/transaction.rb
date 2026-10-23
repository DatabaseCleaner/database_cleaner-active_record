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
          connection_class.connection_pool.pin_connection!(@lock_threads)
          @pinned_depth = pinned_depth + 1
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
          while pinned_depth > 0
            pool.unpin_connection!
            @pinned_depth -= 1
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

      def pinned_depth
        @pinned_depth || 0
      end
    end
  end
end
