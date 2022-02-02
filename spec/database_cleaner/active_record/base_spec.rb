require 'active_record'
require 'database_cleaner/active_record/base'
require 'database_cleaner/spec'
require './spec/support/database_helper'

module DatabaseCleaner
  module ActiveRecord
    RSpec.describe Base do
      subject(:strategy) { described_class.new }

      let(:config_location) { '/path/to/config/database.yml' }

      around do |example|
        DatabaseCleaner::ActiveRecord.config_file_location = config_location
        example.run
        DatabaseCleaner::ActiveRecord.config_file_location = nil
      end

      it_behaves_like 'a database_cleaner strategy'

      describe "db" do
        it "should store my desired db" do
          strategy.db = :my_db
          expect(strategy.db).to eq :my_db
        end

        it "should default to :default" do
          expect(strategy.db).to eq :default
        end
      end

      describe '#db=' do
        let(:my_db) { :my_db }
        let(:config_location) { 'spec/support/example.database.yml' }

        it 'should process erb in the config' do
          strategy.db = my_db
          expect(strategy.connection_hash).to eq({ 'database' => 'one' })
        end

        context 'when ActiveRecord configuration contains a config for the given db' do
          if ::ActiveRecord.version >= Gem::Version.new('6.1')
            context 'ActiveRecord >= 6.1' do
              before do
                allow(::ActiveRecord::Base)
                  .to receive(:configurations).and_return(ac_db_configurations_mock)
                allow(ac_db_configurations_mock)
                  .to receive(:configs_for).with(name: my_db.to_s).and_return(hash_config_mock)
              end

              let(:ac_db_configurations_mock) do
                instance_double(::ActiveRecord::DatabaseConfigurations)
              end
              let(:hash_config_mock) do
                instance_double(
                  ::ActiveRecord::DatabaseConfigurations::HashConfig,
                  configuration_hash: configuration_hash
                )
              end
              let(:configuration_hash) { { 'database' => 'two'} }

              it 'uses the ActiveRecord configuration' do
                strategy.db = my_db
                expect(strategy.connection_hash).to eq(configuration_hash)
              end
            end
          else
            context 'ActiveRecord < 6.1' do
              before do
                allow(::ActiveRecord::Base)
                  .to receive(:configurations).and_return(configurations_hash)
              end
              let(:configurations_hash) { { my_db.to_s => configuration_hash } }
              let(:configuration_hash) { { 'database' => 'two' } }

              it 'uses the ActiveRecord configuration' do
                strategy.db = my_db
                expect(strategy.connection_hash).to eq(configuration_hash)
              end
            end
          end
        end

        context 'when both the config file and ActiveRecord config are not available' do
          before do
            allow(File).to receive(:file?).with(config_location).and_return(false)
          end

          it 'skips the config' do
            strategy.db = my_db
            expect(strategy.connection_hash).not_to be
          end
        end

        context 'when the model is set' do
          it 'skips the config' do
            strategy.db = double(:model_class)
            expect(strategy.connection_hash).not_to be
          end
        end

        context 'when the db is set to :default' do
          it 'skips the config' do
            strategy.db = :default
            expect(strategy.connection_hash).not_to be
          end
        end
      end

      describe "connection_class" do
        it "should default to ActiveRecord::Base" do
          expect(strategy.connection_class).to eq ::ActiveRecord::Base
        end

        context "with database models" do
          let(:model_class) { double }

          context "connection_hash is set" do
            it "reuses the model's connection" do
              strategy.connection_hash = {}
              strategy.db = model_class
              expect(strategy.connection_class).to eq model_class
            end
          end

          context "connection_hash is not set" do
            it "reuses the model's connection" do
              strategy.db = model_class
              expect(strategy.connection_class).to eq model_class
            end
          end
        end

        context "when connection_hash is set" do
          let(:helper) { DatabaseHelper.new(:sqlite3) }
          let(:hash) { helper.send(:default_config) }

          around do |example|
            helper.setup
            strategy.connection_hash = hash
            example.run
            helper.teardown
          end

          context "and there are no models" do
            before do
              allow(::ActiveRecord::Base).to receive(:descendants).and_return([])
            end

            it "establishes a connection with it" do
              expect(::ActiveRecord::Base).to receive(:establish_connection).with(hash)
              expect(strategy.connection_class).to eq ::ActiveRecord::Base
            end
          end

          context "and there are models" do

            it "fetches from connection pool" do
              expect(["Kernel::Agent", "Kernel::User"]).to include(strategy.connection_class.to_s)
            end
          end
        end
      end
    end
  end
end
