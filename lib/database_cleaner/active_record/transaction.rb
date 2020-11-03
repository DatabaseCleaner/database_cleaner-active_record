require 'database_cleaner/active_record/base'

module DatabaseCleaner
  module ActiveRecord
    class Transaction < Base
      Error = Class.new(StandardError)

      case ::ActiveRecord::VERSION::MAJOR
      when 5
        require 'database_cleaner/active_record/rails5'
        include DatabaseCleaner::ActiveRecord::Rails5
      when 6
        require 'database_cleaner/active_record/rails6'
        include DatabaseCleaner::ActiveRecord::Rails6
      else
        raise Error, "Major Rails version #{::Rails::VERSION::MAJOR} is unsupported by database_cleaner"
      end
    end
  end
end

