require 'active_record'
require 'database_cleaner/spec/database_helper'

class DatabaseHelper < DatabaseCleaner::Spec::DatabaseHelper
  def self.with_all_dbs &block
    %w[mysql2 sqlite3 postgres trilogy].map(&:to_sym).each do |db|
      yield new(db)
    end
  end

  def setup
    Kernel.const_set "User", Class.new(ActiveRecord::Base)
    Kernel.const_set "Agent", Class.new(ActiveRecord::Base)
    Kernel.const_set "UserProfile", Class.new(ActiveRecord::Base) if db == :postgres

    super

    connection.execute "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(255));"
    connection.execute "INSERT INTO schema_migrations VALUES (1), (2);"
  end

  def teardown
    connection.execute "DROP TABLE schema_migrations;"

    super

    Kernel.send :remove_const, "User" if defined?(User)
    Kernel.send :remove_const, "Agent" if defined?(Agent)
    Kernel.send :remove_const, "UserProfile" if defined?(UserProfile)
  end

  private

  def establish_connection(config = default_config)
    ActiveRecord::Base.establish_connection(config)
    @connection = ActiveRecord::Base.connection
  end

  def load_schema
    super

    if db == :postgres
      connection.execute <<-SQL
        CREATE TABLE IF NOT EXISTS user_profiles (
          user_id INTEGER,
          FOREIGN KEY(user_id) REFERENCES users(id)
        );
      SQL
    end
  end

  def drop_db
    if db == :postgres
      connection.execute "DROP TABLE IF EXISTS user_profiles"
    end

    super
  end
end
