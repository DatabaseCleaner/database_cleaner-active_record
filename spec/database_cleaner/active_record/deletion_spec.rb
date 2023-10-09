require 'support/database_helper'
require 'database_cleaner/active_record/deletion'

RSpec.describe DatabaseCleaner::ActiveRecord::Deletion do
  subject(:strategy) { described_class.new }

  DatabaseHelper.with_all_dbs do |helper|
    context "using a #{helper.db} connection" do
      around do |example|
        helper.setup
        example.run
        helper.teardown
      end

      let(:connection) { helper.connection }

      describe '#clean' do
        before do
          # Clean should not try to delete from database views. If it does, it will raise an error
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

          it "should delete from all tables" do
            expect { strategy.clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([0,0])
          end

          it "should not reset AUTO_INCREMENT index of table" do
            strategy.clean
            expect(User.create.id).to eq 3
          end

          it "should delete from all tables except for schema_migrations" do
            expect { strategy.clean }
              .to_not change { connection.select_value("select count(*) from schema_migrations;").to_i }
              .from(2)
          end

          it "should only delete from the tables specified in the :only option when provided" do
            expect { described_class.new(only: ['agents']).clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end

          it "should not delete from the tables specified in the :except option" do
            expect { described_class.new(except: ['users']).clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end

          it "should raise an error when invalid options are provided" do
            expect { described_class.new(foo: 'bar') }.to raise_error(ArgumentError)
          end

          it "should not delete from views" do
            allow(strategy.send(:connection)).to receive(:database_cleaner_view_cache).and_return(["users"])

            expect { strategy.clean }
              .to change { [User.count, Agent.count] }
              .from([2,2])
              .to([2,0])
          end
        end

        describe "with pre_count optimization option" do
          subject(:strategy) { described_class.new(pre_count: true) }

          it "only delete from non-empty tables" do
            User.create!

            expect(strategy).to receive(:delete_table).with(strategy.send(:connection), 'users')
            strategy.clean
          end
        end

        context 'when :cache_tables is set to true' do
          subject(:strategy) { described_class.new(cache_tables: true) }

          it 'caches the list of tables to be deleted from' do
            if [:mysql2, :trilogy].include?(helper.db)
              expect(strategy).to receive(:build_table_stats_query).once.and_return("")
            elsif helper.db == :postgres
              expect(strategy.send(:connection)).to receive(:tables_with_schema).once.and_return([])
            else
              expect(strategy.send(:connection)).to receive(:database_tables).once.and_return([])
            end

            strategy.clean
            strategy.clean
          end
        end

        context 'when :cache_tables is set to false' do
          subject(:strategy) { described_class.new(cache_tables: false) }

          it 'does not cache the list of tables to be deleted from' do
            if [:mysql2, :trilogy].include?(helper.db)
              expect(strategy).to receive(:build_table_stats_query).twice.and_return("")
            elsif helper.db == :postgres
              expect(strategy.send(:connection)).to receive(:tables_with_schema).twice.and_return([])
            else
              expect(strategy.send(:connection)).to receive(:database_tables).twice.and_return([])
            end

            strategy.clean
            strategy.clean
          end
        end
      end
    end
  end
end
