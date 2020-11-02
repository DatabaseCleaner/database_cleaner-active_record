require 'database_cleaner/active_record/base'

module DatabaseCleaner
  module ActiveRecord
    class Transaction < Base
      Error = Class.new(StandardError)

      case ::ActiveRecord::VERSION::MAJOR
      when 3
        require 'database_cleaner/active_record/rails3'
        include DatabaseCleaner::ActiveRecord::Rails3
      when 4
        require 'database_cleaner/active_record/rails4'
        include DatabaseCleaner::ActiveRecord::Rails4
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

