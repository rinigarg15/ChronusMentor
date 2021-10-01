require_relative "generators/env_specific_constants"

EMAIL_ENABLED = false
ChronusMentorBase::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  config.autoload_paths += Dir["#{config.root}/demo/code/"]

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching, airbrake
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.force_ssl = false

  # NOTE Set the following constant to true to enable emails in dev mode.
  if EMAIL_ENABLED
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true

    require "smtp_tls"
    ActionMailer::Base.smtp_settings = {
      :address => "smtp.gmail.com",
      :port => 587,
      :domain => "mail.chronus.com",
      :authentication => :plain,
      :user_name => "",
      :password => ""
    }
  else
    # Letter opener gem setting
    config.action_mailer.delivery_method = :letter_opener
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
  end

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log
  config.assets.raise_runtime_errors = true

  # Expands the lines which load the assets
  config.assets.debug = true

  # The asset pipeline now supports a quiet option which suppresses output of asset requests
  config.assets.quiet = true

  # To turn off digest
  config.assets.digest = false

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)

  config.after_initialize do
    Bullet.enable = false
    Bullet.alert = true
    Bullet.bullet_logger = true
    Bullet.console = true
    #  Bullet.growl = false
    #  Bullet.xmpp = false
    Bullet.rails_logger = true
    Bullet.disable_browser_cache = true
  end

end

# Restful Authentication
REST_AUTH_SITE_KEY = 'f5945d1c74d3502f8a3de8562e5bf21fe3fec887'
REST_AUTH_DIGEST_STRETCHES = 10

if "irb" == $0
  ActiveRecord::Base.logger = Logger.new(STDOUT)

  # Util method to find programs in console
  require 'utils'
end


#ActionMailer::Base.default_content_type = "text/html"

DEFAULT_DOMAIN_NAME = 'localhost.com'
EMAIL_HOST_SUBDOMAIN = 'iitm'
DEFAULT_HOST_NAME = DEFAULT_DOMAIN_NAME
SECURE_SUBDOMAIN = 'secure'

# Storage options
VIRUS_SCAN_OPTIONS = {:styles => {:text => {:virus_test => true}},
  :processors => [:virus_scanner]
}

S3_BUCKET_SERVER_SIDE_ENCRYPTION_OPTION = {}

ANNOUNCEMENT_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
ARTICLE_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
DATA_IMPORT_SOURCE_FILE_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
DATA_IMPORT_LOG_FILE_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
POST_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
SOLUTION_PACK_STORAGE_OPTIONS = {}
MOBILE_LOGO_STORAGE_OPTIONS = {}
GROUP_LOGO_STORAGE_OPTIONS = {}
USER_PICTURE_STORAGE_OPTIONS = {}
PROGRAM_CKPHOTOS_STORAGE_OPTIONS = {}
PROGRAM_CKRESOURCES_STORAGE_OPTIONS = {}
CONNECTION_ATTACHMENT_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
COMMON_ANSWER_ATTACHMENT_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
PROFILE_ANSWER_ATTACHMENT_STORAGE_OPTIONS = {}
STYLESHEET_STORAGE_OPTIONS = {}
PRIVATE_NOTE_STORAGE_OPTIONS = {}
MESSAGE_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
USER_CSV_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
TASK_COMMENT_STORAGE_OPTIONS = VIRUS_SCAN_OPTIONS
AUTH_CONFIG_LOGO_STORAGE_OPTIONS = {}

EnvSpecificConstants.generate_with_host_type(StorageConstants, :local, virus_scan: VIRUS_SCAN_OPTIONS)

EnvSpecificConstants.generate_with_host_type(UserConstants, :local)
EnvSpecificConstants.generate_with_host_type(GroupConstants, :local)

MAILGUN_DOMAIN = "developmentmg.realizegoal.com"

#XXX This is a dummy one for tests/dev/cucumber to get assets(images) in mailer.
#look at user_mailer_helper.rb
EMAIL_IMAGE_URL = "http://mentor.chronus.com"

FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS = ['apollodev+sendmail@chronus.com']
FEED_MIGRATION_FAILURE_NOTIFICATION_CHRONUS_RECIPIENTS = []

SALES_DEMO_ORGANIZATION_CREATION_STATUS_NOTIFICATION_RECIPIENTS = ['apollodev+sendmail@chronus.com']

BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS = ['apollodev+sendmail@chronus.com']
ACTIVE_ADMINS_NOTIFICATION_RECIPIENTS = ['tester@chronus.com']

I18n_RESCUE_FORMAT = false
MISSING_HTML_SUFFIX_HANDLERS = [:raise]

DEMO_PROGRAMS_ALLOWED = true
AB_TESTING_ENABLED = true
ENGAGEMENT_INDEX_ENABLED = true
PENDO_TRACKING_ENABLED = false