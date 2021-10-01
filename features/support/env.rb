# IMPORTANT: This file is generated by cucumber-rails - edit at your own peril.
# It is recommended to regenerate this file in the future when you upgrade to a
# newer version of cucumber-rails. Consider adding your own code to a new file
# instead of editing this one. Cucumber will automatically load all features/**/*.rb
# files.
require 'rubygems'
ENV["RAILS_ENV"] ||= "test"
ENV["TIMEOUT_OCCURED"] = 'false'
# The below env is added to suppress browser authentication dialog (actually make it fail)
# for unauthenticated ajax requests which may occur during cucumber test cases.
# See xhr_access_denied method of authenticated_system.rb
#
# One case where it happens is that when a test case access group show and then logs out before the
# more activities ajax request is submitted to the server.
ENV['CUCUMBER_ENV'] ||= 'true'
ENV['BS_RUN'] ||= 'false'
ENV['AXE_RUN'] ||= 'false'

require 'cucumber/rails'
require 'capybara/cucumber'
require 'capybara/rails'
require 'capybara/session'
require 'email_spec'
require 'email_spec/cucumber'
require Rails.root.to_s + '/test/lib/parallel_overrides'
require 'capybara/dsl'


# Enable firebug in the firefox browser profile launched during testing for debugging.
# Note:
#  The scenario needs to be debugged with @firebug tag.
#  Set the FIRE_BUG_VERSION to version of firebug compatible with the specific firefox version
require 'capybara/firebug'
require 'capybara-screenshot/cucumber'

if ENV['FIRE_BUG_VERSION']
  Selenium::WebDriver::Firefox::Profile.firebug_version = "#{ENV['FIRE_BUG_VERSION']}"
end

require File.dirname(__FILE__) +'/../../test/test_helper'
require File.dirname(__FILE__) + '/match_indexing_stub'
require File.dirname(__FILE__) +'/cucumber_util'

require 'socket'
def find_available_port
  server = TCPServer.new('127.0.0.1', 0)
  server.addr[1]
ensure
  server.close if server
end

def stub_matching_index
  puts "Stubbing"
    %w(
        perform_full_index_and_refresh
        perform_program_delta_index_and_refresh
        perform_users_delta_index_and_refresh
        remove_user
    ).each do |method|
      Matching.stubs(method)
    end
  end

def unstub_matching_index
  puts "Unstubbing"
    %w(
        perform_full_index_and_refresh
        perform_program_delta_index_and_refresh
        perform_users_delta_index_and_refresh
        remove_user
    ).each do |method|
      Matching.unstub(method)
    end
  end

def reindex_model(model_name)
  model = model_name.constantize
  includes_list = ElasticsearchConstants::INDEX_INCLUDES_HASH[model.name]
  model.delete_indexes if model.__elasticsearch__.index_exists?
  model.force_create_ex_index
  model.includes(includes_list).eimport
  model.refresh_es_index
end

Capybara.server do |app, port|
  require 'rack/handler/thin'
  Rack::Handler::Thin.run(app, Port: port)
end

if ENV['TDDIUM']
  Capybara.server_port = find_available_port
  Capybara.app_host = "http://lvh.me:#{Capybara.server_port}"
 else
  Capybara.server_port = 9887
  Capybara.app_host = "http://test.host:#{Capybara.server_port}"
end

# Capybara defaults to XPath selectors rather than Webrat's default of CSS3. In
# order to ease the transition to Capybara we set the default here. If you'd
# prefer to use XPath just remove this line and adjust any selectors in your
# steps to use the XPath syntax.

Capybara.default_selector = :css

# Default wait time for AJAX requests
# Increase the default value to avoid tests timing out in load situations
Capybara.default_max_wait_time = 20
Capybara.default_wait_time = 20

Capybara.raise_server_errors = false

# By default, any exception happening in your Rails application will bubble up
# to Cucumber so that your scenario will fail. This is a different from how
# your application behaves in the production environment, where an error page will
# be rendered instead.
#
# Sometimes we want to override this default behaviour and allow Rails to rescue
# exceptions and display an error page (just like when the app is running in production).
# Typical scenarios where you want to do this is when you test your error pages.
# There are two ways to allow Rails to rescue exceptions:
#
# 1) Tag your scenario (or feature) with @allow-rescue
#
# 2) Set the value below to true. Beware that doing this globally is not
# recommended as it will mask a lot of errors for you!
#
ActionController::Base.allow_rescue = false

# By default, cucumber-rails runs `DatabaseCleaner.start` and `DatabaseCleaner.clean` before and after your scenarios. You can disable this behaviour like so:
Cucumber::Rails::Database.autorun_database_cleaner = false

# Remove/comment out the lines below if your app doesn't have a database.
# For some databases (like MongoDB and CouchDB) you may need to use :truncation instead.
begin
  require 'database_cleaner'
  require 'database_cleaner/cucumber'
  DatabaseCleaner.strategy = :transaction
rescue NameError
  raise "You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it."
end


# You may also want to configure DatabaseCleaner to use different strategies for certain features and scenarios.
# See the DatabaseCleaner documentation for details. Example:
#
#   Before('@no-txn,@selenium,@culerity,@celerity,@javascript') do
#     DatabaseCleaner.strategy = :truncation, {except: %w[widgets]}
#   end
#
#   Before('~@no-txn', '~@selenium', '~@culerity', '~@celerity', '~@javascript') do
#     DatabaseCleaner.strategy = :transaction
#   end
#

# Generic Scenario hooks
if !ENV['TDDIUM']
  Before('@javascript') do
    if ENV['HEADLESS'] == 'true'
      require 'headless'

      headless = Headless.new
      headless.start

      # Use webkit instead of browser in headless mode
      Capybara.javascript_driver = :webkit
      at_exit do
        headless.destroy
      end
    end
  end
end

Before('@javascript') do |scenario|
  require 'selenium-webdriver'
  if ENV["TIMEOUT_OCCURED"] == 'true'
    puts "ENV variable TIMEOUT_OCCURED is true"
    assert false
  end
  if ENV['BS_RUN'] == 'true'
    http_client = Selenium::WebDriver::Remote::Http::Default.new
    http_client.timeout = 18000
    username = ENV["BS_USERNAME"]
    access_key = ENV["BS_ACCESS_KEY"]
    endpoint = "http://#{username}:#{access_key}@hub.browserstack.com/wd/hub"
    caps = Selenium::WebDriver::Remote::Capabilities.new
    caps["browser"] = ENV["BS_BROWSER"]
    caps["browser_version"] = ENV["BS_BROWSER_VERSION"]
    caps["os"] = ENV["BS_OS"]
    caps["os_version"] = ENV["BS_OS_VERSION"]
    caps["browserstack.local"] = "true"
    caps["browserstack.localIdentifier"] = ENV["TDDIUM_ASSIGNMENT_ID"]
    caps["browserstack.ie.alternateProxy"] = "true"
    caps["browserstack.ie.enablePopups"] = "true"
    caps["browserstack.selenium_version"] = "2.47.1"
    caps["browserstack.autoWait"] = "0"
    caps["browserstack.video"] = "false"
    caps["resolution"] = "2048x1536"
    caps["build"] = ENV["TDDIUM_SESSION_ID"]
    caps["name"] = scenario.feature.title
    Capybara.register_driver :light_sauce do |app|
      Capybara::Selenium::Driver.new(app, browser: :remote, url: endpoint, desired_capabilities: caps, http_client: http_client)
    end
    Capybara::Screenshot.register_driver(:light_sauce) do |driver, path|
       driver.browser.save_screenshot(path)
    end
    Capybara.current_driver = :light_sauce
    Capybara.javascript_driver = :light_sauce
 else
    Capybara.register_driver :selenium do |app|
      # Uncomment the following line if custom binary is used
      #Selenium::WebDriver::Firefox::Binary.path="/opt/firefox41/firefox"
      profile=Selenium::WebDriver::Firefox::Profile.new
      profile['browser.download.dir']=DOWNLOAD_PATH.to_s
      # use the custom folder defined in "browser.download.dir"
      profile['browser.download.folderList']=2
      profile['browser.dom.max_script_run_time']=1000
      profile['browser.helperApps.neverAsk.saveToDisk']="text/csv,application/pdf,application/excel"
      profile["pdfjs.disabled"] = true
      http_client = Selenium::WebDriver::Remote::Http::Default.new
      if ENV['TDDIUM']
        http_client.timeout = 1000
      else
        http_client.timeout = 120
      end
      Capybara::Selenium::Driver.new(app, browser: :firefox, profile: profile, http_client: http_client)
    end
    Capybara::Screenshot.register_driver(:selenium) do |driver, path|
      driver.browser.save_screenshot(path)
    end
    Capybara::Screenshot.autosave_on_failure = true
    Capybara.current_driver    = :selenium
    Capybara.javascript_driver = :selenium
    if ENV['AXE_RUN'] == 'true'
      require 'axe/cucumber/step_definitions'
      require File.dirname(__FILE__) + '/axe_overrides'
      Axe.configure do |c|
        # browser object
        c.page = :selenium
      end
    end
  end
  begin
    Capybara.current_session.driver.browser.manage.window.resize_to(1920, 1200)
  rescue => e
    if ENV['TDDIUM']
      raise e
    else
      puts "Setting TIMEOUT_OCCURED to true. Error " + e.message
      puts ENV["TIMEOUT_OCCURED"]
      ENV["TIMEOUT_OCCURED"] = 'true'
      puts ENV["TIMEOUT_OCCURED"]
      assert false
    end
  end
end

Before('@webkit') do
  Capybara.javascript_driver = :webkit
  at_exit do
    Capybara.javascript_driver = :selenium
  end
end

Before do |scenario|
  DatabaseCleaner.start
  @scenario_id = scenario.__id__
  @scenario_name = scenario.name
  @count = 1
  if ENV['AXE_RUN'] == 'true'
    @prev_page_content = page.body.to_s
    @skip_afterstep_hook = false
  end
  unless $cm_global_hook_executed

    # Global scenario hooks go here - START

    # Start GC thread to control the GC calls to avoid ruby crashes. We are basically controlling/reducing the number of calls to GC.
    CucumberDeferredGC.start

    # Global scenario hooks go here - END

    $cm_global_hook_executed = true
    $SUBDOMAIN = ''
    $PROGRAM_ROOT = ''
  end
  # Disabling default oauths as all scenarios were written on the assumption that organization will only have
  # chronus_auth enabled.
  AuthConfig.where.not(auth_type: AuthConfig::Type::CHRONUS).update_all(enabled: false)
  reindex_model("User")
  reindex_model("Member")
  stub_matching_index
  if ENV["TIMEOUT_OCCURED"] == 'true'
    puts "ENV variable TIMEOUT_OCCURED is true"
    assert false
  end
end

AfterStep('@javascript') do
  if ENV['AXE_RUN'] == 'true'
    if ((Digest::SHA1.hexdigest(@prev_page_content) == Digest::SHA1.hexdigest(page.body.to_s)) || (@skip_afterstep_hook == true) )
      @prev_page_content = page.body.to_s
      @skip_afterstep_hook = false
    else
      step "the page should be accessible"
      @prev_page_content = page.body.to_s
    end
  end
end

After do |scenario|
  unstub_matching_index
  Timecop.return
  # Use a special log routine since puts is being overridden in capybara scenario hooks and creates problem sequencing of logs
  CucumberLog.log "After \"#{scenario.name}\" : process_size = #{CucumberDeferredGC.process_size}MB"
  if !scenario.failed?
    system("find #{FILE_SAVE_PATH} -type f -regex \".*#{@scenario_id}.*\" -delete")
  end
  puts "In After" + ENV["TIMEOUT_OCCURED"]
  puts ENV["TIMEOUT_OCCURED"] == 'false'
  if ((scenario.failed?) && (Capybara.javascript_driver == Capybara.current_driver) && (ENV["TIMEOUT_OCCURED"] == 'false'))
    if ENV['TDDIUM']
       Capybara.save_path = 'tmp/capybara' # TODO_CAPYBARA_SCREENSHOT_UPGRADE
       Capybara::Screenshot.screenshot_and_save_page
    else   
        puts "In After else" + ENV["TIMEOUT_OCCURED"]
        screenshot_path = 'tmp/cucumber_results/screenshots/' + "#{scenario.feature.file.gsub(/\./,'-').gsub(/.*\//,'')}-#{Time.now.strftime('%Y-%m-%d %H-%M-%S')}.png"
        page.driver.browser.save_screenshot(screenshot_path)
        embed(screenshot_path, "image/png", "SCREENSHOT")
    end     
  end
  if ENV["TIMEOUT_OCCURED"] == 'false'
  tries = 3
    begin
      if Capybara.javascript_driver == Capybara.current_driver
        Capybara.current_session.driver.quit
      end 
    rescue => e
      tries -= 1
      if tries > 0
        retry
      else
        raise e
      end
    end
    DatabaseCleaner.clean
    puts "After Database clean"
  end

end

CucumberWait.set_default_wait_time(Capybara.default_max_wait_time)

if CucumberAjaxCallTracker.enabled?
  AfterStep('@javascript') do
    CucumberAjaxCallTracker.wait_till_ajax_calls_complete(page)
  end
end

AfterStep('@pause') do
  print "Press Return to continue ..."
  STDIN.getc
end

Before '@enable_caching' do
  ActionController::Base.perform_caching = true
end

After '@enable_caching' do
  Rails.cache.clear
  ActionController::Base.perform_caching = false
end

Before '@mobile_v2' do
  if Capybara.current_driver == :selenium
    window = Capybara.current_session.driver.browser.manage.window
    window.resize_to(800, 1280)
  end
  Browser.any_instance.stubs(:ios_webview?).returns(true)
  APP_CONFIG[:cors_origin] = [TEST_ASSET_HOST]
end