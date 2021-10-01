require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Uncomment it to find the source of depreciation warnings
#ActiveSupport::Deprecation.debug = true

Bundler.require(*Rails.groups)

# Load the environment variables
Dotenv.load(File.dirname(__FILE__) + '/.env')

# Patch for https://github.com/rails/rails/issues/1525
module ActionDispatch
  module Routing
    class RouteSet #:nodoc:

      # Since the router holds references to many parts of the system
      # like engines, controllers and the application itself, inspecting
      # the route set can actually be really slow, therefore we default
      # alias inspect to to_s.

      alias inspect to_s
    end
  end
end

unless (Rails.env.development? || Rails.env.test?)
  deploy_config = YAML::load(ERB.new(File.read(File.dirname(__FILE__) + "/deploy.yml")).result)[Rails.env].symbolize_keys
  S3_REGION = ENV["USE_S3_BACKUP_BUCKET"]=="true" ? deploy_config[:s3_backup_region] : deploy_config[:region]
  GLOBAL_ASSETS_REGION = ENV["USE_S3_BACKUP_BUCKET"]=="true" ? deploy_config[:global_assets_backup_region] : deploy_config[:global_assets_region]
else
  S3_REGION, GLOBAL_ASSETS_REGION = "us-east-1", "us-east-1"
end
CHRONUS_MENTOR_ASSETS_BUCKET = ENV["USE_S3_BACKUP_BUCKET"]=="true" ? "chronus-mentor-assets-backup" : "chronus-mentor-assets"
S3_DOMAIN_URL = (S3_REGION == "us-east-1") ? "s3.amazonaws.com" : "s3-#{S3_REGION}.amazonaws.com"
GLOBAL_ASSETS_DOMAIN_URL = (GLOBAL_ASSETS_REGION == "us-east-1") ? "s3.amazonaws.com" : "s3-#{GLOBAL_ASSETS_REGION}.amazonaws.com"

module ChronusMentorBase
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.eager_load_paths += Dir["#{config.root}/lib/populator_v3/**/"]
    config.eager_load_paths += Dir["#{config.root}/lib/**/"]
    config.eager_load_paths += Dir["#{config.root}/app/mailers/**/"]

    require 'safe_cookies'
    require File.join(File.dirname(__FILE__), 'role_constants')
    require File.join(File.dirname(__FILE__), '../lib/ckeditor/engine')
    require File.join(File.dirname(__FILE__), '../lib/matching/init')
    require File.join(File.dirname(__FILE__), '../lib/elasticsearch/chronus_elasticsearch')

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # http://stackoverflow.com/questions/20361428/rails-i18n-validation-deprecation-warning
    config.i18n.enforce_available_locales = true

    config.force_ssl = true
    config.ssl_options = { hsts: { subdomains: false } }

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    #Add this line to include subfolders in the config/locales/ folder
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :passphrase, :password_confirmation, :current_password, :mobile_auth_token, :device_token, :thread, :authenticity_token]

    config.active_record.observers = :user_observer,
      :membership_request_observer,
      :announcement_observer,
      :post_observer,
      :mentor_request_observer,
      :mentor_offer_observer,
      :program_observer,
      :group_observer,
      :common_question_observer,
      :survey_answer_observer,
      :survey_question_observer,
      :qa_answer_observer,
      :article_observer,
      :flag_observer,
      :comment_observer,
      :theme_observer,
      :membership_observer,
      :topic_observer,
      :organization_observer,
      :member_observer,
      :admin_message_observer,
      :meeting_observer,
      :member_meeting_observer,
      'article/publication_observer',
      :mentoring_slot_observer,
      :education_observer,
      :experience_observer,
      :publication_observer,
      :manager_observer,
      :location_observer,
      :profile_answer_observer,
      :profile_question_observer,
      :role_question_observer,
      :program_event_observer,
      :event_invite_observer,
      :qa_question_observer,
      :program_invitation_observer,
      'admin_messages/receiver_observer',
      :abstract_message_observer,
      :coaching_goal_observer,
      :coaching_goal_activity_observer,
      :meeting_request_observer,
      'three_sixty/survey_observer',
      'three_sixty/survey_assessee_observer',
      'three_sixty/survey_answer_observer',
      :'mentoring_model/task_template_observer',
      :'mentoring_model/goal_template_observer',
      :'mentoring_model/milestone_template_observer',
      :'mentoring_model/task_observer',
      :'mentoring_model/activity_observer',
      :mentoring_model_observer,
      :survey_observer,
      :role_observer,
      :project_request_observer,
      :admin_view_observer,
      'campaign_management/email_event_log_observer',
      'mentoring_model/task/comment_observer',
      'campaign_management/abstract_campaign_message_observer',
      'feedback/response_observer',
      'organization_language_observer',
      'career_dev/portal_observer',
      'acts_as_taggable_on/tagging_observer',
      :answer_choice_observer,
      :question_choice_observer, :resource_publication_observer, 'mailer/template_observer', :match_report_admin_view_observer, :match_config_observer

    config.assets.precompile += %w(override_fluidity.scss ie6.css new_base.css v3/application_v3.css v3/application_v3_split2.css v3/application_v3_split3.css v3/application_v3_split4.css v3/application_v3_split5.css v3/application_v3_split6.css v3/overview_pages.css pdf.css v3/application_v3.js ckeditor/* highcharts.js highcharts-ng.js)
    config.assets.precompile += ["jquery-ui-1.8.10.custom.css", "datatables.css"]

    # By default images are included only from app/assets folder.To include vendor images add image extensions in precompile(http://stackoverflow.com/questions/14194752/rails-4-asset-pipeline-vendor-assets-images-are-not-being-precompiled)
    config.assets.precompile += ["*.js", "*.eot", "*.svg", "*.woff", "*.ttf", "*.png", "*.jpg", "*.jpeg", "*.gif"] # Also include any js & css files.

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    #    config.middleware.use "SetCookieDomain"

    config.time_zone = 'Etc/UTC'

    config.eager_load = true

    # Use SQL instead of Active Record's schema dumper when creating the test database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :sql
    config.active_record.dump_schema_after_migration = false

    config.log_tags = [
      -> request { "Request #{request.uuid}" }
    ]
    # Secures cookies
    config.middleware.insert_before ActionDispatch::Cookies, SafeCookies::Middleware

    config_settings = YAML::load(ERB.new(File.read("#{Rails.root}/config/settings.yml")).result)[Rails.env].symbolize_keys

    #adding headers to allow cross-origin request from a particular origin (eg: mentor.chronus.com) for organization verification
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins config_settings[:cors_origin]
        resource "*#{config_settings[:cors_resource_path]}", :headers => :any, :methods => [:get]
      end
    end
    # For xhr requests with attachments, authenticity token is not passed as part of Request Header.
    config.action_view.embed_authenticity_token_in_remote_forms = true

    config.active_job.queue_adapter = :delayed_job

    # Rails use MySQL + mongoDB database. So while generating migration file, error "error  mongoid [not found]"
    # Link: https://stackoverflow.com/questions/11213057/set-default-database-connection-rails
    #
    config.generators do |g|
      g.orm :active_record
    end
  end
end
require 'will_paginate/array'
require 'elasticsearch/rails/instrumentation'
