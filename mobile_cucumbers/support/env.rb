require 'rubygems'

ENV["RAILS_ENV"] ||= "test"
ENV['CUCUMBER_ENV'] ||= 'true'
ENV['MOBILE_CUKE'] ||= 'true'
ENV['BS_RUN'] ||= 'false'


require 'cucumber/rails'
require 'capybara/cucumber'
require 'capybara/rails'
require 'capybara/session'
require 'email_spec'
require 'email_spec/cucumber'
require 'parallel_overrides'
require 'capybara/dsl'
require 'appium_capybara'
require 'appium_lib'
require 'cucumber/ast'

require File.dirname(__FILE__) +'/../../test/test_helper'
require File.dirname(__FILE__) +'/cucumber_util'

require 'socket'
def find_available_port
  server = TCPServer.new('127.0.0.1', 0)
  server.addr[1]
ensure
  server.close if server
end

Capybara.server do |app, port|
  require 'rack/handler/thin'
  Rack::Handler::Thin.run(app, :Port => port)
end

Capybara.server_host = '0.0.0.0' # Listen to all interfaces
Capybara.server_port = 9887
Capybara.app_host = "http://test.host:#{Capybara.server_port}" 

Capybara.default_selector = :css 
Capybara.default_wait_time = 20
Capybara.raise_server_errors = false
ActionController::Base.allow_rescue = false
Cucumber::Rails::Database.autorun_database_cleaner = false


begin
  require 'database_cleaner'
  require 'database_cleaner/cucumber'
  DatabaseCleaner.strategy = :transaction
rescue NameError
  raise "You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it."
end
  

Before('@javascript') do |scenario|
  require 'selenium-webdriver'
      Capybara.register_driver(:appium) do |app|
      opts = Appium.load_appium_txt file: File.join(Dir.pwd, '/mobile_cucumbers/support/ios/appium.txt')
      $wait = Selenium::WebDriver::Wait.new(:timeout => 30) 
      Appium::Capybara::Driver.new app, opts
    end
      Capybara.default_driver = :appium
      Capybara.current_driver    = :appium
      Capybara.javascript_driver = :appium
      $driver = Capybara.current_session.driver.appium_driver
      $driver.set_wait(30)
end

Before do |scenario|
  DatabaseCleaner.start
  unless $cm_global_hook_executed
    $cm_global_hook_executed = true
    $SUBDOMAIN = ''
    $PROGRAM_ROOT = ''
  end
end

After do |scenario|
  sleep(5)
  DatabaseCleaner.clean
  Timecop.return
  puts "After \"#{scenario.title}\" : process_size = #{CucumberDeferredGC.process_size}MB"
  puts "Closing App"
  $driver.close_app
  $driver.driver_quit
  Capybara.current_session.driver.quit
end
