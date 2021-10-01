# NOTE: Do not add instance variables to this controller unless it can be re-used across several controllers.
class ApplicationController < ActionController::Base

  # Protect from forgery prepends the verify_authenticity_token filter. The order in which it is being called should not matter as long as our custom filters donot prepend before this.
  protect_from_forgery with: :exception
  include DjSourcePriorityHelper
  include AuthenticatedSystem
  include TabConfiguration
  include SimpleCaptcha::ControllerHelpers
  include LanguagesHelper
  include RemotipartOverrides::RenderOverrides
  include TranslationsService
  include DateTranslationHelper
  include CkeditorHelpersControllers
  include ActionView::Helpers::SanitizeHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::OutputSafetyHelper
  include ChronusSanitization::HelperMethods
  include ChronusAbTest
  include ApplicationHelper
  include AuthenticationExtensions
  include TabConfigurationHelper::Base
  include ApplicationControllerExtensions::CurrentObjects
  include ApplicationControllerExtensions::ActionGroups
  include ApplicationControllerExtensions::ActionEvents::Base
  include ApplicationControllerExtensions::CommonChecks
  include ApplicationControllerExtensions::Helpers
  include ApplicationControllerExtensions::MobileApp
  include ApplicationControllerExtensions::NewRelic
  include ApplicationControllerExtensions::RenderingHelpers

  helper :all # include all helpers, all the time

  layout :choose_layout
  attr_accessor :current_program, :current_domain, :current_wob_member, :current_root, :current_organization

  # Generic getters
  helper_method :get_current_user, :program_context, :global_search_current_user_role_ids

  # Checks
  helper_method :logged_in_program?, :logged_in_at_current_level?, :working_on_behalf?, :program_view?, :super_user_or_feature_enabled?,
    :organization_view?, :show_program_selector?, :is_membership_form_enabled?, :is_ie_less_than?, :super_console?, :mobile_device?, :is_mobile_app?,
    :is_external_link?, :is_iab?, :can_view_programs_listing_page?

  # For proxy session handling
  helper_method :foreign_domain?, :proxy_session

  # traslations service
  helper_method(*translated_methods)

  # Setter methods
  helper_method :current_root, :current_user, :current_program, :current_organization, :current_program_or_organization, :current_user_or_member, :current_user_or_wob_member,
    :current_member_or_cookie, :wob_member

  # A/B Testing methods
  helper_method :chronus_ab_test, :chronus_ab_test_only_use_cookie, :finished_chronus_ab_test, :finished_chronus_ab_test_only_use_cookie, :participating_in_ab_test?,
    :alternative_choosen_in_ab_test, :chronus_ab_test_get_experiment

  before_action :set_web_dj_priority # This should be at the top of all the before filters

  before_action :handle_last_visited_program, :log_request_details, :setup_proxy_session, :set_uniq_cookie_token

  before_action :load_current_root, :load_current_organization, :handle_secondary_url, :handle_inactive_organization, :load_current_program,
    :login_required_in_program, :require_organization, :require_program
  before_action :handle_set_mobile_auth_cookie, :handle_set_locale, :set_locale_from_cookie_or_member, :set_terminology_helpers, :get_pending_requests_count_for_quick_links
  before_action :configure_program_tabs, :set_time_zone, :check_feature_access, :check_browser, :set_session_expiry_cookie, :show_mobile_prompt,
    :handle_terms_and_conditions_acceptance, :update_last_seen_at, :handle_pending_profile_or_unanswered_required_qs, :check_ip_authentication, :configure_mobile_tabs
  before_action :instrument_request_for_newrelic, :skip_apdex_for_newrelic
  before_action :set_cache_header, :set_org_id_and_program_id_for_newrelic, :set_traffic_origin_for_newrelic, :set_dj_organization_id
  after_action :copy_from_proxy_session_to_parent_session, :audit_activity
  after_action :set_current_program_cookie, if: :is_mobile_app?

  # Simple method do to do sublayouts:
  # http://mattmccray.com/archive/2007/02/19/Sorta_Nested_Layouts/huurl
  #
  # The default sublayout is nil
  def sub_layout
    nil
  end

  unless Rails.application.config.consider_all_requests_local
    rescue_from Exception, with: :handle_exceptions
  end

  def handle_exceptions(exception)
    report_and_render_error_page(exception)
    notify_airbrake(exception) unless skip_airbrake?(exception)
  end

  protected

  def skip_airbrake?(exception)
    exception == ActionController::InvalidAuthenticityToken && params[:controller] == "sessions" && params[:action] == "destroy"
  end

  def report_and_render_error_page(exception)
    case exception
    when Authorization::PermissionDenied
      render_error_page("403", "common_text.error_msg.permission_denied".translate)
    when ActiveRecord::RecordNotFound
      render file: File.join(Rails.root, 'public', '404'), formats: [:html], status: 404, layout: false
    when ActionController::InvalidAuthenticityToken
      render_error_page("500", "common_text.error_msg.csrf_logout_message".translate)
    else
      render_error_page("500", "common_text.error_msg.something_went_wrong".translate)
    end
  end

  def render_error_page(error_code, message, render_layout = true)
    report_error message, file: File.join(Rails.root, 'app/views/common', error_code), formats: [:html], handlers: [:erb], layout: render_layout
  end

  # Reports an error in the request by showing the +message+ as flash message and
  # redirecting to root_path.
  #
  # To avoid recursive redirection where the root_path page itself is throwing
  # error, we +render+ a special error page when an error happens for a second
  # time.
  #
  # +params[:error_raised]+ is used for that purpose to track previous errors.
  # When it is set, the special error page is rendered as per +render_opts+.
  # Else, redirected to root_path.
  #
  def report_error(message, render_opts)
    return if performed?

    if params[:error_raised]
      # Clear any error message in the flash while rendering the special page.
      flash[:error] = nil

      # We already saw some error in the previous request. Just render and return.
      render render_opts
    else
      # Show a flash message and redirect to root path with error_raised set to 1
      respond_to do |format|
        format.html do
          flash[:error] = message
          redirect_to root_path(error_raised: 1)
        end
        format.any { head :ok }
      end
    end
  end

  # Use programs layout if inside programs context, default otherwise.
  #
  def choose_layout
    # Use program layout if logged in and not first time edit program page.
    return 'application' unless @current_organization && !is_first_program_edit?
    return 'program' if logged_in_organization?
    'program_non_logged_in'
  end

  def is_first_program_edit?
    params[:controller] == 'programs' && params[:action] == 'edit' && params[:first_visit]
  end
end