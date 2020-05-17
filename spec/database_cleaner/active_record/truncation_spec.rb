require 'support/database_helper'
require 'database_cleaner/active_record/truncation'

RSpec.describe DatabaseCleaner::ActiveRecord::Truncation do
  subject(:strategy) { described_class.new }

  DatabaseHelper.with_all_dbs do |helper|
    context "using a #{helper.db} connection" do
      around do |example|
        helper.setup
        example.run
        helper.teardown
      end

      let(:connection) { helper.connection }

      before do
        allow(strategy.send(:connection)).to receive(:disable_referential_integrity).and_yield
        allow(strategy.send(:connection)).to receive(:database_cleaner_view_cache).and_return([])
      end

      describe '#clean' do
        before do
          # Clean should not try to truncate database views. If it does, it will raise an error
          connection.execute "CREATE VIEW view1 AS SELECT * FROM schema_migrations;"
        end

        after do
          connection.execute "DROP VIEW view1"
        end

        context "with records" do
          before do
            2.times { User.create! }
            2.times { Agent.create! }
          end

          it "should truncate all tables" do
            expect { strategy.clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([0,0])
          end

          it "should reset AUTO_INCREMENT index of table" do
            strategy.clean
            expect(User.create.id).to eq 1
          end

          it "should truncate all tables except for schema_migrations" do
            strategy.clean
            count = connection.select_value("select count(*) from schema_migrations;").to_i
            expect(count).to eq 2
          end

          it "should only truncate the tables specified in the :only option when provided" do
            expect { described_class.new(only: ['agents']).clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end

          it "should not truncate the tables specified in the :except option" do
            expect { described_class.new(except: ['users']).clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end

          it "should raise an error when invalid options are provided" do
            expect { described_class.new(foo: 'bar') }.to raise_error(ArgumentError)
          end

          it "should not truncate views" do
            allow(strategy.send(:connection)).to receive(:database_cleaner_view_cache).and_return(["users"])

            expect { strategy.clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end
        end

        describe "with pre_count optimization option" do
          subject(:strategy) { described_class.new(pre_count: true) }

          it "only truncates non-empty tables" do
            User.create!

            expect(strategy.send(:connection)).to receive(:truncate_tables).with(['users'])
            strategy.clean
          end
        end

        context 'when :cache_tables is set to true' do
          subject(:strategy) { described_class.new(cache_tables: true) }

          it 'caches the list of tables to be truncated' do
            expect(strategy.send(:connection)).to receive(:database_cleaner_table_cache).and_return([])
            expect(strategy.send(:connection)).not_to receive(:tables)

            allow(strategy.send(:connection)).to receive(:truncate_tables)
            subject.clean
          end
        end

        context 'when :cache_tables is set to false' do
          subject(:strategy) { described_class.new(cache_tables: false) }

          it 'does not cache the list of tables to be truncated' do
            expect(strategy.send(:connection)).not_to receive(:database_cleaner_table_cache)
            expect(strategy.send(:connection)).to receive(:database_tables).and_return([])

            allow(strategy.send(:connection)).to receive(:truncate_tables)
            strategy.clean
          end
        end
      end
    end
  end
end
