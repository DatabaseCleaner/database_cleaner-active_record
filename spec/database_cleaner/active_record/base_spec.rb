require 'active_record'
require 'database_cleaner/active_record/base'
require 'database_cleaner/spec'

RSpec.describe DatabaseCleaner::ActiveRecord do
  it_behaves_like "a database_cleaner adapter"

  it "has a default_strategy of transaction" do
    expect(described_class.default_strategy).to eq(:transaction)
  end

  describe "config_file_location" do
    after do
      # prevent global state leakage
      DatabaseCleaner::ActiveRecord.config_file_location = nil
    end

    it "should default to \#{Dir.pwd}/config/database.yml" do
      DatabaseCleaner::ActiveRecord.config_file_location = nil
      expect(DatabaseCleaner::ActiveRecord.config_file_location).to \
        eq "#{Dir.pwd}/config/database.yml"
    end
  end
end

module DatabaseCleaner
  module ActiveRecord
    class ExampleStrategy
      include DatabaseCleaner::ActiveRecord::Base
    end

    RSpec.describe ExampleStrategy do
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

      describe "db=" do
        let(:config_location) { "spec/support/example.database.yml" }

        it "should process erb in the config" do
          strategy.db = :my_db
          expect(strategy.connection_hash).to eq({ "database" => "one" })
        end

        context 'when config file differs from established ActiveRecord configuration' do
          before do
            allow(::ActiveRecord::Base).to receive(:configurations).and_return({ "my_db" => { "database" => "two"} })
          end

          it 'uses the ActiveRecord configuration' do
            strategy.db = :my_db
            expect(strategy.connection_hash).to eq({ "database" => "two"})
          end
        end

        context 'when config file agrees with ActiveRecord configuration' do
          before do
            allow(::ActiveRecord::Base).to receive(:configurations).and_return({ "my_db" => { "database" => "one"} })
          end

          it 'uses the config file' do
            strategy.db = :my_db
            expect(strategy.connection_hash).to eq({ "database" => "one"})
          end
        end

        context 'when ::ActiveRecord::Base.configurations nil' do
          before do
            allow(::ActiveRecord::Base).to receive(:configurations).and_return(nil)
          end

          it 'uses the config file' do
            strategy.db = :my_db
            expect(strategy.connection_hash).to eq({ "database" => "one"})
          end
        end

        context 'when ::ActiveRecord::Base.configurations empty' do
          before do
            allow(::ActiveRecord::Base).to receive(:configurations).and_return({})
          end

          it 'uses the config file' do
            strategy.db = :my_db
            expect(strategy.connection_hash).to eq({ "database" => "one"})
          end
        end

        context 'when config file is not available' do
          before do
            allow(File).to receive(:file?).with(config_location).and_return(false)
          end

          it "should skip config" do
            strategy.db = :my_db
            expect(strategy.connection_hash).not_to be
          end
        end

        it "skips the file when the model is set" do
          strategy.db = double(:model_class)
          expect(strategy.connection_hash).not_to be
        end

        it "skips the file when the db is set to :default" do
          # to avoid https://github.com/bmabey/database_cleaner/issues/72
          strategy.db = :default
          expect(strategy.connection_hash).not_to be
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
          let(:hash) { {} }
          before { strategy.connection_hash = hash }

          it "establishes a connection with it" do
            expect(::ActiveRecord::Base).to receive(:establish_connection).with(hash)
            expect(strategy.connection_class).to eq ::ActiveRecord::Base
          end
        end
      end
    end
  end
end
