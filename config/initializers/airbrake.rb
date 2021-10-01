require_relative "./load_config.rb"
require 'airbrake'
require 'airbrake/delayed_job'

Airbrake::Notifier.module_eval do
  LOW_PRIORITY_EXCEPTIONS = ["ActiveRecord::RecordNotFound",
                             "AbstractController::ActionNotFound",
                             "ActionView::MissingTemplate",
                             "Authorization::PermissionDenied",
                             "Geokit::Geocoders::GeocodeError",
                             "ActionController::RoutingError",
                             "ActionController::InvalidAuthenticityToken"]

  def notify(exception, params = {}, &block)
    set_env_low(exception)
    send_notice(exception, params, default_sender, &block)
  end

  def notify_sync(exception, params = {}, &block)
    set_env_low(exception)
    send_notice(exception, params, @sync_sender, &block).value
  end

  private

  # Moves low priority exceptions to environment_low
  def set_env_low(exception)
    exception[:context].merge!(:environment => "#{::Rails.env}_low") if exception.is_a?(Airbrake::Notice) && exception[:errors].any?{ |error| LOW_PRIORITY_EXCEPTIONS.include?(error[:type]) }
  end
end

# Look at https://github.com/airbrake/airbrake/blob/master/lib/airbrake/configuration.rb for default configurations
Airbrake.configure do |config|
  config.project_key = APP_CONFIG[:airbrake_project_key]
  config.project_id  = APP_CONFIG[:airbrake_project_id]
  config.environment = Rails.env
  # Comment the below line to debug airbrake from development or test environment.
  config.ignore_environments = %w(development test)
  config.blacklist_keys = Rails.application.config.filter_parameters
end

# sub-keys are taking more time to process - https://github.com/airbrake/airbrake/pull/639
# ENV_VARIABLES_TO_BE_SKIPPED = %w(AIRBRAKE_API_KEY AIRBRAKE_PROJECT_KEY AIRBRAKE_PROJECT_ID AWS_PROD_API_KEY AWS_PROD_API_SECRET DATABASE_PWD MAILGUN_API_KEY NEWRELIC_LICENSE_KEY REPLY_TO_EMAIL_PASSWORD S3_KEY S3_SECRET SUPER_CONSOLE_PASS_PHRASE ZENDESK_SHARED_SECRET APN_KEY PHRASEAPP_STYLEGUIDE_CODE PHRASEAPP_APOLLODEV_ACCESS_TOKEN PHRASEAPP_PROJECT_ID_CONTENT_DEVELOP PHRASEAPP_PROJECT_ID_MOBILE_PRODUCTION PHRASEAPP_PROJECT_ID_PRODUCTION PHRASEAPP_PROJECT_ID_STAGING action_dispatch.logger action_dispatch.backtrace_cleaner action_dispatch.remote_ip action_controller.instance action_dispatch.secret_key_base action_dispatch.secret_token action_dispatch.routes async.callback async.close action_dispatch.key_generator PASSENGER_CONNECT_PASSWORD HTTP_COOKIE action_dispatch.cookies rack.request.cookie_hash rack.request.cookie_string rack.request.form_vars rack.session rack.session.options rack.session.record)

# Pass only the expected values to Airbrake tool
WHITE_LISTED_ENV_VARIABLES = %w(HTTPS HTTP_REFERER HTTP_HOST ORIGINAL_FULLPATH PATH_INFO REMOTE_ADDR REMOTE_PORT REQUEST_METHOD SERVER_NAME SERVER_PORT SERVER_PROTOCOL SERVER_SOFTWARE)

Airbrake.add_filter do |notice|
  notice[:environment].merge!(notice.stash[:rack_request].env.pick(*WHITE_LISTED_ENV_VARIABLES)) if notice.stash[:rack_request].present?
  # To avoid duplicate error entries in the dashboard, ignore the ActiveJob wrapper
  notice.ignore! if notice[:context][:action] == 'ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper'
end