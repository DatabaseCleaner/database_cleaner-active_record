require "bundler/setup"
require "byebug"

if ENV['COVERAGE'] == 'true'
  require "simplecov"

  if ENV['CI'] == 'true'
    require 'codecov'
    SimpleCov.formatter = SimpleCov::Formatter::Codecov
    puts "required codecov"
  end

  # ensure all test run coverage results are merged
  command_name = File.basename(ENV["BUNDLE_GEMFILE"])
  SimpleCov.command_name command_name
  SimpleCov.start
  puts "started simplecov: #{command_name}"
end

require 'database_cleaner-active_record'

RSpec.configure do |config|
  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.disable_monkey_patching!
end
