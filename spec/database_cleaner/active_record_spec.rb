require 'database_cleaner/active_record'
require 'database_cleaner/spec'

RSpec.describe DatabaseCleaner::ActiveRecord do
  it_behaves_like "a database_cleaner adapter"

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
