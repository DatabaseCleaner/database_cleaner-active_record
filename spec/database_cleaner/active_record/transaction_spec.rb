require 'support/database_helper'
require 'database_cleaner/active_record/transaction'

RSpec.describe DatabaseCleaner::ActiveRecord::Transaction do
  subject(:strategy) { described_class.new }

  describe "options" do
    it "accepts :lock_threads" do
      expect { described_class.new(lock_threads: false) }.to_not raise_error
    end

    it "rejects unknown options" do
      expect { described_class.new(only: []) }.to raise_error(ArgumentError)
    end
  end

  DatabaseHelper.with_all_dbs do |helper|
    context "using a #{helper.db} connection" do
      around do |example|
        helper.setup
        example.run
        helper.teardown
      end

      describe "#clean" do
        context "after an initial #start" do
          before do
            strategy.start
            2.times { User.create! }
            2.times { Agent.create! }
          end

          it "should clean all tables" do
            expect { strategy.clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([0,0])
          end
        end

        context "with fixtures before an initial #start" do
          before do
            2.times { User.create! }
            strategy.start
            2.times { Agent.create! }
          end

          it "should not clean fixtures" do
            expect { strategy.clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end
        end

        context "without an initial start" do
          before do
            2.times { User.create! }
            2.times { Agent.create! }
          end

          it "does nothing" do
            expect { strategy.clean }
              .to_not change { [User.count, Agent.count] }
          end
        end
      end

      if ActiveRecord.version >= Gem::Version.new("7.2")
        describe "connection pinning" do
          let(:pool) { ActiveRecord::Base.connection_pool }

          after { strategy.clean }

          it "keeps the uncommitted records visible after an executor wrap releases connections" do
            strategy.start
            User.create!

            ActiveRecord::ConnectionAdapters::ConnectionPool::ExecutorHooks.complete(nil)

            # Another thread (e.g. the pool reaper) checks out the released connection meanwhile
            leased, done = Queue.new, Queue.new
            holder = Thread.new do
              pool.lease_connection
              leased << true
              done.pop
              pool.release_connection
            end
            leased.pop

            expect(User.count).to eq 1
          ensure
            done << true
            holder.join
          end

          it "shares the connection with other threads" do
            strategy.start
            User.create!

            expect(Thread.new { User.count }.value).to eq 1
          end

          it "unpins the connection on #clean" do
            strategy.start
            connection = pool.lease_connection
            strategy.clean

            expect(connection.transaction_open?).to be false
            expect(pool.lease_connection.transaction_open?).to be false
          end
        end
      end

      describe "#cleaning" do
        context "with records" do
          it "should clean all tables" do
            strategy.cleaning do
              2.times { User.create! }
              2.times { Agent.create! }
              expect([User.count, Agent.count]).to eq [2,2]
            end
            expect([User.count, Agent.count]).to eq [0,0]
          end
        end

        context "with fixtures" do
          it "should not clean fixtures" do
            2.times { User.create! }
            strategy.cleaning do
              2.times { Agent.create! }
              expect([User.count, Agent.count]).to eq [2,2]
            end
            expect([User.count, Agent.count]).to eq [2,0]
          end
        end

        context "without an initial start" do
          it "does nothing" do
            2.times { User.create! }
            2.times { Agent.create! }
            expect { strategy.cleaning {} }
              .to_not change { [User.count, Agent.count] }
              .from([2,2])
          end
        end
      end
    end
  end
end
