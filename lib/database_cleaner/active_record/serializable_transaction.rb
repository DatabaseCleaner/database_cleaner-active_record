# See: https://github.com/DatabaseCleaner/database_cleaner/pull/681
return if Gem::Version.new(DatabaseCleaner::VERSION) < Gem::Version.new("2.0.2")

# See: https://github.com/rails/rails/pull/55542
return if ActiveRecord.gem_version < Gem::Version.new("8.1.0")

module DatabaseCleaner
  module ActiveRecord
    class SerializableTransaction < Transaction
      TRANSACTION_PARAMETERS = { isolation: :serializable }.freeze
    end
  end
end
