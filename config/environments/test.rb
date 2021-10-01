require_relative "generators/env_specific_constants"

ChronusMentorBase::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  config.eager_load = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_files = true
  config.static_cache_control = "public, max-age=3600"

  config.force_ssl = false

  # Log error messages when you accidentally call methods on nil
  
   config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = false

  # These files will be populated during the execution of the task 'db:generate_fixtures'
  # The task requires the translations to be reloaded after pseudo localization
  # And, only the file paths specified in load_path will be considered for reloading
  ["de", "es"].each do |locale|
    file_path = File.join("test", "locales", "test_phrase.#{locale}.yml")
    next if File.exist?(file_path)

    File.open(file_path, "w") { |f| f.write("---\n#{locale}:") }
  end
  config.i18n.load_path += Dir[Rails.root.join('test/locales/*.yml').to_s]

  config.active_support.test_order = :random

  # https://github.com/grosser/parallel_tests/wiki
  config.cache_store = :file_store, Rails.root.join("tmp", "cache", "paralleltests#{ENV['TEST_ENV_NUMBER']}")
  config.assets.cache = Sprockets::Cache::FileStore.new(Rails.root.join("tmp/cache/assets/paralleltests#{ENV['TEST_ENV_NUMBER']}"))

  REST_AUTH_SITE_KEY = 'f5945d1c74d3502f8a3de8562e5bf21fe3fec887'
  REST_AUTH_DIGEST_STRETCHES = 10

  if ENV['TDDIUM']
    DEFAULT_HOST_NAME = 'lvh.me'
    DEFAULT_DOMAIN_NAME = 'lvh.me'
    TEST_ASSET_HOST = "http://primary.lvh.me:3001"
  else
    DEFAULT_HOST_NAME = 'test.host'
    DEFAULT_DOMAIN_NAME = 'test.host'
    TEST_ASSET_HOST = "http://primary.test.host:9887"
  end
  EMAIL_HOST_SUBDOMAIN = 'primary'
  SECURE_SUBDOMAIN = 'secure'

  # Set this to false when running rails server in test environment
  # because webrick doesn't support SSL. As a result login will fail with SSL error in browser.
  # Starting a rails server in test env is very useful when debugging
  # against the test database.

  S3_BUCKET_SERVER_SIDE_ENCRYPTION_OPTION = {}

  # Storage options

  ANNOUNCEMENT_STORAGE_OPTIONS = {}
  ARTICLE_STORAGE_OPTIONS = {}
  DATA_IMPORT_SOURCE_FILE_STORAGE_OPTIONS = {}
  DATA_IMPORT_LOG_FILE_STORAGE_OPTIONS = {}
  SOLUTION_PACK_STORAGE_OPTIONS = {}
  MOBILE_LOGO_STORAGE_OPTIONS = {}
  GROUP_LOGO_STORAGE_OPTIONS = {}
  USER_PICTURE_STORAGE_OPTIONS = {}
  POST_STORAGE_OPTIONS = {}
  PROGRAM_CKPHOTOS_STORAGE_OPTIONS = {}
  PROGRAM_CKRESOURCES_STORAGE_OPTIONS = {}
  PROFILE_ANSWER_ATTACHMENT_STORAGE_OPTIONS = {}
  CONNECTION_ATTACHMENT_STORAGE_OPTIONS = {}
  COMMON_ANSWER_ATTACHMENT_STORAGE_OPTIONS = {}
  STYLESHEET_STORAGE_OPTIONS = {}
  PRIVATE_NOTE_STORAGE_OPTIONS = {}
  MESSAGE_STORAGE_OPTIONS = {}
  USER_CSV_STORAGE_OPTIONS = {}
  TASK_COMMENT_STORAGE_OPTIONS = {}
  AUTH_CONFIG_LOGO_STORAGE_OPTIONS = {}

  EnvSpecificConstants.generate_with_host_type(StorageConstants, :local)

# Uncomment this to have db log stmts go to a separate file. Cleaner logs and faster tests
# ActiveRecord::Base.logger = Logger.new('log/db-test.log')

#  config.action_controller.asset_host                  = Proc.new do |file_name, req|
#    if (req.respond_to?(:headers) && req.headers['Accept-Encoding'].blank?)
#      ""
#    else
#      TEST_ASSET_HOST
#    end
#  end

  config.action_controller.asset_host = Proc.new do |*args|
    _file_name, req = args
    TEST_ASSET_HOST unless req.nil?
  end

  EnvSpecificConstants.generate_with_host_type(UserConstants, :local)
  EnvSpecificConstants.generate_with_host_type(GroupConstants, :local)

  MAILGUN_DOMAIN = "testmg.realizegoal.com"

  # This is to turn off benchmarking the tests by default
  # http://railspikes.com/2009/4/3/rails-test-benchmarks#comment-form
  #ENV['BENCHMARK'] ||= 'none'

  #XXX This is a dummy one for tests/dev/cucumber to get assets(images) in mailer.
  #look at user_mailer_helper.rb
  EMAIL_IMAGE_URL = "http://mentor.chronus.com"

  # Running the test suite generates log file of ~1GB - which is a lot!
  # And, this article https://jtway.co/speed-up-your-rails-test-suite-by-6-in-1-line-13fedb869ec4 claims that
  # disabling logs speeds running time by 6%.
  unless ENV['RAILS_ENABLE_TEST_LOG']
    config.logger = Logger.new(nil)
    config.log_level = :fatal
  end
end

FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS = ['tester@chronus.com']
FEED_MIGRATION_FAILURE_NOTIFICATION_CHRONUS_RECIPIENTS = ['mentor.test.support@chronus.com']

SALES_DEMO_ORGANIZATION_CREATION_STATUS_NOTIFICATION_RECIPIENTS = ['tester@chronus.com']

BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS = ['tester@chronus.com']
ACTIVE_ADMINS_NOTIFICATION_RECIPIENTS = ['tester@chronus.com']

I18n_RESCUE_FORMAT = false
I18n.exception_handler = :raise_translation_missing_exception
MISSING_HTML_SUFFIX_HANDLERS = [:log]

DEMO_PROGRAMS_ALLOWED = true
AB_TESTING_ENABLED = false

NegativeCaptcha.test_mode = true

if ENV['TDDIUM']
  DOWNLOAD_PATH = Dir.tmpdir + "/downloads"
  FILE_SAVE_PATH = Rails.root.join("test/fillin_screenshots")
  WCAG_LOG_FILE = Rails.root.join("test/wcag_errors")
else
  DOWNLOAD_PATH = Rails.root.join("tmp/downloads") # downloaded files will be stored here
  FILE_SAVE_PATH = Rails.root.join("tmp/fillin_screenshots")
  WCAG_LOG_FILE = Rails.root.join("tmp/wcag_errors")
end
ENGAGEMENT_INDEX_ENABLED = false
PENDO_TRACKING_ENABLED = false
