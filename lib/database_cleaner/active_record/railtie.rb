# frozen_string_literal: true

module DatabaseCleaner::ActiveRecord
  class Railtie < ::Rails::Railtie
    initializer "database_cleaner-active_record" do
      ActiveSupport.on_load(:active_record) do
        require "database_cleaner/active_record"
      end
    end
  end
end
