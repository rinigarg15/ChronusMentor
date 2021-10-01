# Load the rails application
require File.expand_path('../application', __FILE__)
# The subdomain that points to app landing page i.e., mentor.chronus.com
# Any change in DEFAULT_SUBDOMAIN for production/productioneu, have to be taken care in HostingRegions::SUBDOMAIN_MAPPING
DEFAULT_SUBDOMAIN = 'mentor'
DEFAULT_DEMO_SUBDOMAIN = 'mentor.demo'
REDIRECT_SUBDOMAIN = 'www'

# Just an unintelligble name for session id rather than call
# it session_id or sid or auth_id
SID_PARAM_NAME = :_idfs

# Initialize the rails application
ChronusMentorBase::Application.initialize!
Ckeditor::ApplicationController.skip_before_action :login_required_in_program, :require_program, :configure_program_tabs, :configure_mobile_tabs, :set_time_zone, :check_feature_access, :handle_pending_profile_or_unanswered_required_qs, :check_browser, :set_session_expiry_cookie, :back_mark_pages
