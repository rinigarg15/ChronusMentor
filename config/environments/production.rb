require_relative "generators/env_specific_constants"

ChronusMentorBase::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

	# Log error messages when you accidentally call methods on nil.
	config.whiny_nils = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_files = false

  # Compress JavaScripts and CSS
  config.assets.compress = false

  # Fallback to assets pipeline if a precompiled asset is missed
  # This is essential for ckeditor related assets
  config.assets.compile = true

  config.assets.debug = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to Rails.root.join("public/assets")
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  config.log_level = :info

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  ASSETS_BUCKET_URL = ENV["USE_S3_BACKUP_BUCKET"]=="true" ? "d3sgw9z0y2nobp.cloudfront.net" : "d28ysuyw2f6yxp.cloudfront.net"
  ASSETS_HOST_URL = "mentor.chronus.com"
  EMAIL_HOST_SUBDOMAIN = "mentor"
  SECURE_SUBDOMAIN = 'secure'

	# Enable serving of images, stylesheets, and javascripts from an asset server
  require 'rack/accept'

  config.action_controller.asset_host                  = Proc.new do |*args|
      file_name, req = args

    unless req.nil?
      if ( (req.respond_to?(:headers) && !Rack::Accept::Encoding.new(req.headers['Accept-Encoding']).accept?('gzip')) || file_name.starts_with?('/assets/ckeditor') )
        # Serve the assets from rails server in the below cases, Otherwise serve from CDN
        #    1. For browsers which can't handle compressed assets
        #    2. For all ckeditor relaed assets
        if req.respond_to?(:headers)
          puts "#{Time.now} asset_host : delivering uncompressed asset from #{ASSETS_HOST_URL}: headers => "
          for header in req.env.select {|k,v| k=~/^(HTTP|CONTENT)_/}
            puts "#{header[0].split('_',2)[1]} -> #{header[1]}"
          end
        end
        puts "#{Time.now} asset_host : delivering ckeditor asset from #{ASSETS_HOST_URL} : url : #{file_name}" if file_name.starts_with?('/assets/ckeditor')
        "#{req.protocol}#{ASSETS_HOST_URL}"
      else
        "#{req.protocol}#{ASSETS_BUCKET_URL}"
      end
    end
  end

	config.action_mailer.delivery_method = :sendmail
	ActionMailer::Base.delivery_method = :sendmail
	config.action_mailer.perform_deliveries = true
	config.action_mailer.raise_delivery_errors = true

	require "smtp_tls"

	# ActionMailer::Base.default_content_type = "text/html"

end



# Restful Authentication
REST_AUTH_SITE_KEY = 'f5945d1c74d3502f8a3de8562e5bf21fe3fec887'
REST_AUTH_DIGEST_STRETCHES = 10

DEFAULT_DOMAIN_NAME = 'chronus.com'
DEFAULT_HOST_NAME = DEFAULT_DOMAIN_NAME

ENABLE_S3_SERVER_SIDE_ENCRYPTION = true
S3_BUCKET_SERVER_SIDE_ENCRYPTION_OPTION = {"x-amz-server-side-encryption" => "AES256"}

GENERAL_OPTIONS = {
  :storage => :s3,
  :bucket => ENV["USE_S3_BACKUP_BUCKET"]=="true" ? 'chronus-mentor-backup' : 'chronus-mentor',
  :s3_protocol => "https",
  :s3_host_name => S3_DOMAIN_URL,
  :use_timestamp => false,
  :s3_headers => S3_BUCKET_SERVER_SIDE_ENCRYPTION_OPTION,
  s3_region: S3_REGION
}

VIRUS_SCAN_OPTIONS = {:styles => {:text => {:virus_test => true}},
  :processors => [:virus_scanner]
}

SECURE_URL_OPTIONS = {:s3_permissions => 'authenticated-read',
  :url => ":s3_secured_url",
  :expires_in => 60.minutes,
  :escape_url => false
}


# Storage options
ANNOUNCEMENT_STORAGE_OPTIONS = {:path => "announcements/attachments/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

POST_STORAGE_OPTIONS = {:path => "posts/attachments/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

ARTICLE_STORAGE_OPTIONS = {:path => "article_contents/attachments/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

DATA_IMPORT_SOURCE_FILE_STORAGE_OPTIONS = {:path => "data_imports/attachments/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

DATA_IMPORT_LOG_FILE_STORAGE_OPTIONS = {:path => "data_imports/logs/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

SOLUTION_PACK_STORAGE_OPTIONS = {:path => "programs/content_packs/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

MOBILE_LOGO_STORAGE_OPTIONS = {:path => "programs/mobile_logos/:id/:style.:extension"
}.merge(GENERAL_OPTIONS)

GROUP_LOGO_STORAGE_OPTIONS = {:path => "groups/logos/:id/:style.:extension"
}.merge(GENERAL_OPTIONS)

USER_PICTURE_STORAGE_OPTIONS = {:path => "users/pictures/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(SECURE_URL_OPTIONS).merge(:expires_in => 7.days)

PROGRAM_CKPHOTOS_STORAGE_OPTIONS = {:path => "programs/ckphotos/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS).merge(:expires_in => 15.minutes)

PROGRAM_CKRESOURCES_STORAGE_OPTIONS = {:path => "programs/ckattachements/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS).merge(:expires_in => 15.minutes)

STYLESHEET_STORAGE_OPTIONS = {
  :path => "programs/stylesheets/:id/:basename.:extension"
}.merge(GENERAL_OPTIONS)

# s3_permissions is authenticated-read because the scrap attachments are private to mentors and mentees
CONNECTION_ATTACHMENT_STORAGE_OPTIONS = {
  :path => "connections/attachments/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

COMMON_ANSWER_ATTACHMENT_STORAGE_OPTIONS = {
  :path => "common_answers/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

PROFILE_ANSWER_ATTACHMENT_STORAGE_OPTIONS = {
  :path => "profile_answers/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(SECURE_URL_OPTIONS)

PRIVATE_NOTE_STORAGE_OPTIONS = {
  :path => "connections/private_notes/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

MESSAGE_STORAGE_OPTIONS = {
  :path => "messages/attachments/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

USER_CSV_STORAGE_OPTIONS = {
  :path => "user_csv/attachments/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

TASK_COMMENT_STORAGE_OPTIONS = {
  :path => "mentoring_model_task_comments/attachments/:id/:style/:basename.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

AUTH_CONFIG_LOGO_STORAGE_OPTIONS = {
  :path => "auth_configs/logos/:id/:style.:extension"
}.merge(GENERAL_OPTIONS).merge(VIRUS_SCAN_OPTIONS).merge(SECURE_URL_OPTIONS)

EnvSpecificConstants.generate_with_host_type(StorageConstants, :hosted, general: GENERAL_OPTIONS, secure_url: SECURE_URL_OPTIONS, virus_scan: VIRUS_SCAN_OPTIONS)
EnvSpecificConstants.generate_with_host_type(UserConstants, :hosted)
EnvSpecificConstants.generate_with_host_type(GroupConstants, :hosted)

module ApdexConstants
  # List of org for which app apdex and end user apdex not to be calculated, other performance metrics will be present
  SKIP_APDEX_LIST = []

  # List of org for which end user apdex not to be calculated
  SKIP_ENDUSER_APDEX_LIST = [842]
  #842 =>"entrepreneur.tonyelumelufoundation.org"
end

EnvSpecificConstants.generate(CronMonitorConstants, "production")

MAILGUN_DOMAIN = "mentormg.chronus.com"

EMAIL_IMAGE_URL = "http://#{ASSETS_HOST_URL}"

FEED_MIGRATION_STATUS_NOTIFICATION_CHRONUS_RECIPIENTS = ['clientops@chronus.com', 'apollodev@chronus.com']
FEED_MIGRATION_FAILURE_NOTIFICATION_CHRONUS_RECIPIENTS = ['support@chronus.com']

BOUNCED_MAIL_AND_SPAM_NOTIFICATION_RECIPIENTS = ['opseng@chronus.com']
ACTIVE_ADMINS_NOTIFICATION_RECIPIENTS = ["cs@chronus.com", "cseng@chronus.com"]

I18n_RESCUE_FORMAT = "html"
I18n.exception_handler = :missing_translation_silent_notifier
MISSING_HTML_SUFFIX_HANDLERS = [:log, :airbrake_notify]
AB_TESTING_ENABLED = true

EMAIL_MONITOR_ORG_URL = "https://pingdom-alert.chronus.com"
ENGAGEMENT_INDEX_ENABLED = true
PENDO_TRACKING_ENABLED = true
PAGERDUTY_NOTIFICATION = true
CALENDAR_SYNC_NOTIFICATION_URL = "https://mentor.chronus.com/calendar_sync"
