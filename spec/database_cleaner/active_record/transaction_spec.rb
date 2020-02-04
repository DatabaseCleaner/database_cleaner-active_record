require 'support/active_record_helper'
require 'database_cleaner/active_record/transaction'

RSpec.describe DatabaseCleaner::ActiveRecord::Transaction do
  subject(:strategy) { described_class.new }

  ActiveRecordHelper.with_all_dbs do |helper|
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
