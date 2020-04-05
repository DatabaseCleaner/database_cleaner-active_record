require 'database_cleaner/active_record/version'
require 'database_cleaner/core'
require 'database_cleaner/active_record/deletion'
require 'database_cleaner/active_record/transaction'
require 'database_cleaner/active_record/truncation'

DatabaseCleaner[:active_record].strategy = :transaction
