require_relative './../test_helper.rb'

class DummyApplicationController < ApplicationController
  rescue_from Exception, with: :handle_exceptions
  before_action :filter_dummy
  skip_all_action_callbacks only: [:action_without_filters]
  skip_before_action :login_required_in_program, only: [:action_skipping_login]
  skip_before_action :login_required_in_program, :require_program, only: [:org_level_action]

  def proper_action
    # For testing RoutingError
    head :ok
  end

  def record_not_found_action
    raise ActiveRecord::RecordNotFound
  end

  def error_action
    raise AbstractController::ActionNotFound
  end

  def invalid_auth_action
    raise Authorization::PermissionDenied
  end

  def invalid_authenticity_token
    raise ActionController::InvalidAuthenticityToken
  end

  def unknown_error
    raise "Some error"
  end

  def action_without_filters
    #Filters are not called here
    head :ok
  end

  def action_skipping_login
    head :ok
  end

  def org_level_action
    head :ok
  end

  def export
    send_csv("test-data", disposition: "attachment; filename=test.csv")
  end

  def do_redirect_action
    do_redirect(about_path)
  end

  private

  def filter_dummy
    # Dummy Filter
  end
end

class ApplicationControllerTest < ActionController::TestCase
  tests DummyApplicationController

  def setup
    super
    current_user_is :f_admin
    @redirect_url = "http://annauniv." + DEFAULT_DOMAIN_NAME + "/p/albers"
  end

  def test_skip_all_action_callbacks
    DummyApplicationController.any_instance.expects(:filter_dummy).never
    get :action_without_filters
  end

  def test_filter_being_called
    DummyApplicationController.any_instance.expects(:filter_dummy).once
    get :proper_action
    assert response.headers["X-Robots-Tag"].nil?
  end

  def test_invalid_form_request
    get :invalid_authenticity_token
    assert_redirected_to root_path(error_raised: 1)
  end

  def test_record_not_found
    get :record_not_found_action
    assert_response :missing
    assert_template file: "#{Rails.root}/public/404.html"
  end

  def test_repeated_500_internal_error
    flash[:error] = 'Hello'

    get :error_action, params: { error_raised: 1}
    assert_response :success
    assert_template file: "#{Rails.root}/app/views/common/500.html.erb", layout: "layouts/program"
    assert flash[:error].nil?
  end

  def test_403_auth
    get :invalid_auth_action
    assert_redirected_to root_path(error_raised: 1)
    assert_equal "You are not authorized to access the page", flash[:error]
  end

  def test_uniq_token_cookie
    get :proper_action, params: {uniq_token: "uniq_token"}
    assert_response :success
    assert_equal cookies[:uniq_token], "uniq_token"
  end

  def test_error_redirect_only_if_it_responds_to_html
    @request.env['HTTP_ACCEPT'] = "application/javascript"
    get :invalid_auth_action, xhr: true
    assert_false @response.redirect?
    assert_false @response.body.present?
  end

  def test_repeated_403_auth
    get :invalid_auth_action, params: { error_raised: 1}
    assert_response :success
    assert_template file: "#{Rails.root}/app/views/common/403.html.erb", layout: "layouts/program"
    assert flash[:error].nil?
  end

  def test_unknown_error
    get :unknown_error
    assert_redirected_to root_path(error_raised: 1)
    assert_equal "We're sorry, but something went wrong", flash[:error]
  end

  def test_unknown_error_repeat
    get :unknown_error, params: { error_raised: 1}
    assert_response :success
    assert_template file: "#{Rails.root}/app/views/common/500.html.erb", layout: "layouts/program"
    assert flash[:error].nil?
  end

  def test_robots_tag_header
    SecuritySetting.any_instance.stubs(:allow_search_engine_indexing?).returns(false)

    get :proper_action, params: { format: :mp4}
    assert_response :success
    assert_equal response.headers["X-Robots-Tag"], "noindex"
  end

  def test_set_current_program_cookie_valid_program_case
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(true)
    current_member_is :f_admin

    get :proper_action
    assert_response :success
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/", cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_show_mobile_prompt_with_mobile_view_disabled
    @controller.stubs(:mobile_browser?).returns(true)
    current_member_is :f_admin
    programs(:org_primary).enable_feature(FeatureName::MOBILE_VIEW, false)
    get :proper_action
    assert_response :success
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
  end

  def test_show_mobile_prompt_with_mobile_view_enabled
    @controller.stubs(:mobile_browser?).returns(true)
    programs(:org_primary).enable_feature(FeatureName::MOBILE_VIEW, true)
    current_member_is :f_admin

    get :proper_action
    assert_response :redirect
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
  end

  def test_set_current_program_cookie_valid_program_non_logged_in_case
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(true)
    @controller.stubs(:logged_in_organization?).returns(false)
    request.session[:member_id] = nil

    get :action_skipping_login
    assert_response :success
    assert_false assigns[:current_member]
    assert_nil assigns[:current_user]
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/", cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_set_current_program_cookie_non_program_valid_case
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(true)
    current_member_is :f_admin
    @current_user = nil
    @controller.unstub(:current_root)
    current_program_is nil

    get :org_level_action
    assert_response :success
    assert_nil assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/", cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_set_current_program_cookie_should_not_be_set_on_redirect
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(true)
    current_member_is :f_admin
    @current_user = nil
    @controller.unstub(:current_root)
    current_program_is nil

    get :proper_action
    assert_response :redirect
    assert_nil assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_redirected_to "http://test.host/programs"
    assert_nil cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_set_current_program_cookie_invalid_case
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(false)
    current_member_is :f_admin

    get :proper_action
    assert_response :success
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_nil cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_get_pending_requests_count_for_quick_links_before_action_for_mentee_matching
    current_user_is :student_1

    user = users(:student_1)
    program = programs(:albers)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)

    assert program.matching_by_mentee_alone?

    get :proper_action
    assert_response :success

    assert_equal 2, user.sent_mentor_requests.active.count
    assert_equal 0, assigns(:new_mentor_requests_count)
    assert_equal user.sent_mentor_requests.count, assigns(:past_requests_count)
    assert_equal 0, assigns(:cumulative_requests_notification_count)
    assert_not_equal assigns(:past_requests_count), assigns(:cumulative_requests_notification_count)
    assert_nil assigns(:new_meeting_requests_count)
    assert_nil assigns(:new_mentor_offers)
    assert_nil assigns(:new_mentor_offers_count)
  end

  def test_get_pending_requests_count_for_quick_links_before_action_for_no_past_requests
    current_user_is :student_1

    user = users(:student_1)
    program = programs(:albers)

    user.sent_mentor_requests.destroy_all

    assert program.matching_by_mentee_alone?

    get :proper_action
    assert_response :success

    assert_equal 0, assigns(:past_requests_count)
    assert_equal 1, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_for_quick_links_before_action_for_no_past_requests_with_group
    current_user_is :mkr_student
    user = users(:mkr_student)
    User.any_instance.expects(:get_unanswered_program_events).returns([]).twice
    user.sent_meeting_requests.destroy_all
    get :proper_action
    assert_response :success

    assert user.groups.present?
    assert_equal 0, assigns(:past_requests_count)
    assert_equal 0, assigns(:cumulative_requests_notification_count)
  end


  def test_get_pending_requests_count_for_quick_links_before_action_for_no_past_requests_for_mentor
    current_user_is :mentor_7

    program = programs(:albers)
    program.enable_feature(FeatureName::OFFER_MENTORING)

    User.any_instance.stubs(:get_unanswered_program_events).returns([])

    get :proper_action
    assert_response :success

    assert_equal 0, assigns(:past_requests_count)
    assert_equal 0, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_for_quick_links_before_action_for_mentee_with_calendar_and_mentor_offer
    current_user_is :student_1
    user = users(:student_1)
    program = programs(:albers)
    mentor = users(:f_mentor)

    program.enable_feature(FeatureName::CALENDAR)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)
    Member.any_instance.stubs(:get_upcoming_not_responded_meetings_count).returns(10)

    create_mentor_offer(student: user, mentor: mentor)
    create_meeting_request(mentor: mentor, student: user, status: AbstractRequest::Status::NOT_ANSWERED)

    get :proper_action
    assert_response :success
    assert_equal 2, user.sent_mentor_requests.active.count
    assert_equal 0,assigns(:new_mentor_requests_count)
    assert_equal 1, user.sent_meeting_requests.active.count
    assert_equal 0, assigns(:new_meeting_requests_count)
    assert_equal user.received_mentor_offers.pending, assigns(:new_mentor_offers)
    assert_equal user.received_mentor_offers.pending.count, assigns(:new_mentor_offers_count)
    assert_equal user.sent_mentor_requests.count + user.sent_meeting_requests.count + user.received_mentor_offers.count, assigns(:past_requests_count)
    assert_equal 10, assigns(:upcoming_meetings_count)
    assert_equal 10 + user.received_mentor_offers.pending.count, assigns(:cumulative_requests_notification_count)
    assert assigns(:notification_quick_links).include?(MobileTab::QuickLink::MentorOffer)
    assert assigns(:notification_quick_links).include?(MobileTab::QuickLink::MeetingRequest)
  end

  def test_get_pending_requests_count_for_flash_only_program
    user = users(:student_1)
    current_user_is user
    program = user.program
    program.enable_feature(FeatureName::CALENDAR)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)

    Program.any_instance.stubs(:ongoing_mentoring_enabled?).returns(false)
    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)
    Member.any_instance.stubs(:get_upcoming_not_responded_meetings_count).returns(10)

    get :proper_action
    assert_response :success

    assert_nil assigns(:new_mentor_requests_count)
    assert_equal user.sent_meeting_requests.active.count, assigns(:new_meeting_requests_count)
    assert_nil assigns(:new_mentor_offers)
    assert_equal user.sent_meeting_requests.count, assigns(:past_requests_count)
    assert_equal 10, assigns(:upcoming_meetings_count)
    assert_equal 10 + user.sent_meeting_requests.active.count, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_with_programs_events_disabled
    current_user_is :f_mentor
    program = users(:f_mentor).program
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    get :proper_action
    assert_response :success
    assert_nil assigns(:program_events)
    assert_false assigns(:notification_quick_links).include?(MobileTab::QuickLink::ProgramEvent)
    assert_equal 11, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_with_programs_events_enabled
    current_user_is :f_mentor
    program = users(:f_mentor).program
    get :proper_action
    assert_response :success
    assert_equal [program_events(:birthday_party)], assigns(:unanswered_program_events)
    assert_equal 1, assigns(:unanswered_program_events_count)
    assert assigns(:notification_quick_links).include?(MobileTab::QuickLink::ProgramEvent)
    assert_equal 12, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_for_quick_links_for_user_with_calendar_and_not_opting_for_onetime
    current_user_is :student_1
    user = users(:student_1)
    mentor = users(:mentor_3)
    program = programs(:albers)

    program.enable_feature(FeatureName::CALENDAR)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)

    assert_false user.member.meetings.of_program(program).present?

    Member.any_instance.stubs(:get_upcoming_not_responded_meetings_count).returns(10)
    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(false)

    create_meeting_request(mentor: mentor, student: user, status: AbstractRequest::Status::NOT_ANSWERED)

    get :proper_action
    assert_response :success

    assert_equal 2, user.sent_mentor_requests.active.count
    assert_equal 0, assigns(:new_mentor_requests_count)
    assert_equal 1, user.sent_meeting_requests.active.count
    assert_equal 0, assigns(:new_meeting_requests_count)
    assert_equal user.sent_mentor_requests.count + user.sent_meeting_requests.count, assigns(:past_requests_count)
    assert_nil assigns(:upcoming_meetings_count)
    assert_equal 3, user.sent_mentor_requests.active.count + user.sent_meeting_requests.active.count
    assert_equal 0, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_for_quick_links_before_action_for_mentor_with_calendar_and_mentor_offer_and_opting_for_ongoing_only
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)

    program.enable_feature(FeatureName::CALENDAR)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    assert user.member.meetings.of_program(program).present?

    Member.any_instance.stubs(:get_upcoming_not_responded_meetings_count).returns(10)
    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)

    create_mentor_offer(student: users(:student_1), mentor: user)

    get :proper_action
    assert_response :success

    assert_equal user.received_mentor_requests.active.count, assigns(:new_mentor_requests_count)
    assert_equal user.received_meeting_requests.active.count, assigns(:new_meeting_requests_count)
    assert_equal user.sent_mentor_offers.pending, assigns(:new_mentor_offers)
    assert_equal 1, user.sent_mentor_offers.pending.count
    assert_equal 0, assigns(:new_mentor_offers_count)
    assert_equal user.received_mentor_requests.count + user.received_meeting_requests.count + user.sent_mentor_offers.count, assigns(:past_requests_count)
    assert_equal 10, assigns(:upcoming_meetings_count)
    assert_equal 10 + user.received_mentor_requests.active.count + user.received_meeting_requests.active.count, assigns(:cumulative_requests_notification_count)
  end

  def test_project_requests_count_quick_links_admin
    current_user_is :f_admin_pbe
    user = users(:f_admin_pbe)
    program = user.program

    get :proper_action
    assert_response :success

    project_requests_count = program.project_requests.active.count

    assert_equal project_requests_count, assigns(:new_project_requests_count)
    assert assigns(:past_requests_count).present?
    assert_equal project_requests_count, assigns(:cumulative_requests_notification_count)
  end

  def test_project_requests_count_quick_links_owner
    user = users(:f_mentor_pbe)
    group = user.groups.first
    group.membership_of(user).update_attributes!(owner: true)

    current_user_is user

    create_project_request(group, users(:f_student_pbe))
    get :proper_action
    assert_response :success
    assert_equal 1, assigns(:new_project_requests_count)
    assert assigns(:past_requests_count).present?
    assert_equal 1, assigns(:cumulative_requests_notification_count)
  end

  def test_get_pending_requests_count_for_quick_links_before_action_for_only_group_meeetings_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)

    program.enable_feature(FeatureName::CALENDAR, false)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    program.update_attribute(:mentor_offer_needs_acceptance, true)

    assert user.member.meetings.of_program(program).present?

    Member.any_instance.stubs(:get_upcoming_not_responded_meetings_count).returns(10)
    User.any_instance.stubs(:can_be_shown_meetings_listing?).returns(true)

    create_mentor_offer(student: users(:student_1), mentor: user)

    get :proper_action
    assert_response :success

    assert_equal user.received_mentor_requests.active.count, assigns(:new_mentor_requests_count)
    assert_equal user.sent_mentor_offers.pending, assigns(:new_mentor_offers)
    assert_equal 1, user.sent_mentor_offers.pending.count
    assert_equal 0, assigns(:new_mentor_offers_count)
    assert_equal user.received_mentor_requests.count + user.sent_mentor_offers.count, assigns(:past_requests_count)
    assert_equal 10, assigns(:upcoming_meetings_count)
    assert_equal 10 + user.received_mentor_requests.active.count, assigns(:cumulative_requests_notification_count)
    assert assigns(:notification_quick_links).include?(MobileTab::QuickLink::MentorRequest)
  end

  def test_configure_mobile_tabs
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    group = groups(:mygroup)
    get :proper_action
    assert_response :success
    assert_equal ["Home", "Mentoring Connections", "Requests", "Messages", "More"], @controller.mobile_tabs.collect(&:label)
    assert_equal 5, @controller.mobile_tabs.size
    assert_equal [group_path(group, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), "Mentoring Connections"], [@controller.mobile_tabs[1].url, @controller.mobile_tabs[1].label]
  end

  def test_configure_mobile_tabs_admin_only
    current_user_is :f_admin
    get :proper_action
    assert_response :success
    assert_equal ["Home", "Manage", "Messages", "More"], @controller.mobile_tabs.collect(&:label)
    assert_equal 4, @controller.mobile_tabs.size
  end

  def test_configure_mobile_pbe_tabs
    current_user_is :f_mentor_pbe
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Discover")
    discover_tab = @controller.mobile_tabs.find{|tab| tab.label == "Discover"}
    assert_equal find_new_groups_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), discover_tab.url
    assert_equal "fa-search", discover_tab.iconclass
    assert @controller.mobile_tabs.collect(&:label).include?("Mentoring Connections")
    circles_tab = @controller.mobile_tabs.find{|tab| tab.label == "Mentoring Connections"}
    assert_equal "#", circles_tab.url
    assert_equal "fa-users", circles_tab.iconclass

    assert @controller.mobile_tabs.collect(&:label).include?("Notifications")
    notifications_tab = @controller.mobile_tabs.find{|tab| tab.label == "Notifications"}
    assert_equal "#", notifications_tab.url
    assert_equal "fa-bell-o", notifications_tab.iconclass

    assert_equal ["Home", "Discover", "Mentoring Connections", "Notifications",  "More"], @controller.mobile_tabs.collect(&:label)
    assert_equal 5, @controller.mobile_tabs.size
  end

  def test_configure_mobile_pbe_tabs_admin_only
    current_user_is :f_admin_pbe
    get :proper_action
    assert_response :success
    assert_false @controller.mobile_tabs.collect(&:label).include?("Discover") 
    assert_false @controller.mobile_tabs.collect(&:label).include?("Mentoring Connections")
    assert_equal ["Home", "Notifications", "Manage", "More"], @controller.mobile_tabs.collect(&:label)
    assert_equal 4, @controller.mobile_tabs.size
  end

  def test_configure_mobile_connections_tab_with_single_connection
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    group = groups(:mygroup)
    get :proper_action
    assert_response :success
    connection_tab = @controller.mobile_tabs.find{|tab| tab.label == "Mentoring Connections"}
    assert_equal [group_path(group, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), "Mentoring Connections",  ""], [connection_tab.url, connection_tab.label, connection_tab.mobile_tab_badge]
  end

  def test_configure_mobile_connections_tab_with_many_connections
    current_user_is :student_2
    program = programs(:albers)
    get :proper_action
    assert_response :success
    connection_tab = @controller.mobile_tabs.find{|tab| tab.label == "Mentoring Connections"}
    assert_equal ["#", "Mentoring Connections", "cjs_connections_tab"], [connection_tab.url, connection_tab.label, connection_tab.mobile_tab_class]
  end

  def test_configure_mobile_match_tab_for_student
    current_user_is :f_student
    user = users(:f_student)
    program = programs(:albers)
    user.groups.active.update_all(status: Group::Status::PENDING)
    user.reload
    get :proper_action
    assert_response :success

    match_tab = @controller.mobile_tabs.find{|tab| tab.label == "Match"}
    assert_equal users_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), match_tab.url
    assert_equal "fa-user-circle", match_tab.iconclass
  end

  def test_configure_mobile_match_tab_for_mentor
    current_user_is :f_mentor
    user = users(:f_mentor)
    user.program.enable_feature(FeatureName::OFFER_MENTORING)
    user.groups.active.update_all(status: Group::Status::PENDING)
    user.reload
    get :proper_action
    assert_response :success

    match_tab = @controller.mobile_tabs.find{|tab| tab.label == "Match"}
    assert_equal users_path(view: RoleConstants::STUDENTS_NAME, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), match_tab.url
    assert_equal "fa-user-circle", match_tab.iconclass
  end

  def test_configure_mobile_meetings_tab_with_only_flash_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = user.program
    program.enable_feature(FeatureName::CALENDAR, true)
    program.update_attribute(:engagement_type, Program::EngagementType::CAREER_BASED)
    meeting = meetings(:upcoming_calendar_meeting)
    meeting.update_meeting_time(Time.now + 10.days, 1800.00)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Meetings")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Meetings"}
    assert_equal member_path(user.member, tab:  MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), request_tab.url
    assert_equal "fa-calendar", request_tab.iconclass
  end

  def test_configure_mobile_meetings_tab_with_both_ongoing_and_flash_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = user.program
    program.enable_feature(FeatureName::CALENDAR, true)
    meeting = meetings(:upcoming_calendar_meeting)
    meeting.update_meeting_time(Time.now + 10.days, 1800.00)
    get :proper_action
    assert_response :success
    assert_false @controller.mobile_tabs.collect(&:label).include?("Meetings")
  end

  def test_configure_mobile_requests_tab
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)

    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Requests")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Requests"}
    assert_equal "#", request_tab.url
    assert_equal "fa-user-plus", request_tab.iconclass
    assert_equal "cjs_footer_total_requests", request_tab.mobile_tab_class
  end

  def test_configure_mobile_requests_tab_with_only_mentor_requests_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)

    program.enable_feature(FeatureName::CALENDAR, false)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    program.enable_feature(FeatureName::OFFER_MENTORING, false)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Requests")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Requests"}
    assert_equal mentor_requests_path({filter: AbstractRequest::Filter::TO_ME, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION}), request_tab.url
    assert_equal "fa-user-plus", request_tab.iconclass
    assert_nil request_tab.mobile_tab_class
  end

  def test_configure_mobile_requests_tab_with_only_meetings_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)

    program.enable_feature(FeatureName::CALENDAR, false)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.enable_feature(FeatureName::OFFER_MENTORING, false)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Meetings")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Meetings"}
    assert_equal member_path(user.member, tab:  MembersController::ShowTabs::AVAILABILITY, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), request_tab.url
    assert_equal "fa-calendar", request_tab.iconclass
    assert_equal "cjs_footer_upcoming_meetings", request_tab.mobile_tab_class
  end

  def test_configure_mobile_requests_tab_with_only_mentor_offer_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)

    program.enable_feature(FeatureName::CALENDAR, false)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    program.enable_feature(FeatureName::OFFER_MENTORING)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS, false)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Requests")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Requests"}
    assert_equal mentor_offers_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), request_tab.url
    assert_equal "fa-user-plus", request_tab.iconclass
    assert_nil request_tab.mobile_tab_class
  end

  def test_configure_mobile_requests_tab_with_only_program_events_enabled
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    program.update_column(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)

    program.enable_feature(FeatureName::CALENDAR, false)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    program.enable_feature(FeatureName::OFFER_MENTORING, false)
    program.organization.enable_feature(FeatureName::PROGRAM_EVENTS)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Events")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Events"}
    assert_equal program_events_path(src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), request_tab.url
    assert_equal "fa-calendar", request_tab.iconclass
    assert_nil request_tab.mobile_tab_class
  end

  def test_configure_mobile_messages_tab
    current_user_is :f_mentor
    user = users(:f_mentor)
    program = programs(:albers)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Messages")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Messages"}
    assert_equal messages_path(:organization_level => true, src: EngagementIndex::Src::BrowseMentors::FOOTER_NAVIGATION), request_tab.url
    assert_equal "fa-envelope", request_tab.iconclass
    assert_equal "cjs_footer_messages", request_tab.mobile_tab_class
  end

  def test_configure_mobile_messages_tab_for_admin
    current_user_is :f_admin
    user = users(:f_mentor)
    program = programs(:albers)
    get :proper_action
    assert_response :success
    assert @controller.mobile_tabs.collect(&:label).include?("Messages")
    request_tab = @controller.mobile_tabs.find{|tab| tab.label == "Messages"}
    assert_equal "#", request_tab.url
    assert_equal "fa-envelope", request_tab.iconclass
    assert_equal "cjs_footer_messages", request_tab.mobile_tab_class
  end

  def test_handle_last_visited_program
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(true)
    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = @redirect_url
    @request.cookies[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = cookie[MobileV2Constants::CURRENT_PROGRAM_COOKIE]

    get :proper_action, params: { last_visited_program: true}
    assert_response :redirect
    assert_equal cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE], @redirect_url
    assert_match /#{@redirect_url}/, response.body
  end

  def test_handle_last_visited_program_not_mobile_app
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(false)
    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = @redirect_url
    @request.cookies[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = cookie[MobileV2Constants::CURRENT_PROGRAM_COOKIE]

    get :proper_action, params: { last_visited_program: true}
    assert_response :success #should not redirect
    # should not reset existing cookie value
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_equal @redirect_url, cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_handle_last_visited_program_last_visited_not_set
    Browser::Platform.any_instance.stubs(:ios_webview?).returns(true)
    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = @redirect_url
    @request.cookies[MobileV2Constants::CURRENT_PROGRAM_COOKIE] = cookie[MobileV2Constants::CURRENT_PROGRAM_COOKIE]

    get :proper_action, params: { last_visited_program: false}
    #should not redirect but set cookie, since it is a mobile app
    assert_response :success
    assert_equal programs(:albers), assigns[:current_program]
    assert_equal programs(:org_primary), assigns[:current_organization]
    assert_equal "http://primary.#{DEFAULT_HOST_NAME}/p/albers/", cookies.signed[MobileV2Constants::CURRENT_PROGRAM_COOKIE]
  end

  def test_check_browser__logged_in__unsupported_browser
    member = members(:f_admin)
    assert_nil member.browser_warning_shown_at

    @request.session[:browser_warning_shown] = true
    @controller.stubs(:browser_supported_with_warning?).returns(false)
    @controller.stubs(:is_unsupported_browser?).returns(true)
    current_member_is member
    get :proper_action
    assert_redirected_to upgrade_browser_path
    assert assigns[:invalid_browser]
    assert_nil assigns(:supported_with_warning_browser)
    assert_nil member.reload.browser_warning_shown_at
  end

  def test_check_browser__unlogged_in__unsupported_browser
    @request.session[:browser_warning_shown] = true
    @controller.stubs(:browser_supported_with_warning?).returns(false)
    @controller.stubs(:is_unsupported_browser?).returns(true)
    get :proper_action
    assert_redirected_to upgrade_browser_path
    assert assigns[:invalid_browser]
    assert_nil assigns(:supported_with_warning_browser)
  end

  def test_check_browser__logged_in__to_be_deprecated
    member = members(:f_admin)
    assert_nil member.browser_warning_shown_at
    assert_nil @request.session[:browser_warning_shown]

    Member.any_instance.stubs(:can_show_browser_warning?).returns(true)
    @controller.stubs(:browser_supported_with_warning?).returns(true)
    @controller.stubs(:is_unsupported_browser?).returns(false)
    current_member_is member
    get :proper_action
    assert_response :success
    assert_false assigns[:invalid_browser]
    assert_equal true, assigns(:supported_with_warning_browser)
    assert_equal true, @request.session[:browser_warning_shown]
    assert_not_nil member.reload.browser_warning_shown_at
  end

  def test_check_browser__logged_in__to_be_deprecated__warning_shown
    member = members(:f_admin)
    assert_nil member.browser_warning_shown_at
    assert_nil @request.session[:browser_warning_shown]

    Member.any_instance.stubs(:can_show_browser_warning?).returns(false)
    @controller.stubs(:browser_supported_with_warning?).returns(true)
    @controller.stubs(:is_unsupported_browser?).returns(false)
    current_member_is member
    get :proper_action
    assert_response :success
    assert_false assigns[:invalid_browser]
    assert_nil assigns(:supported_with_warning_browser)
    assert_nil @request.session[:browser_warning_shown]
    assert_nil member.reload.browser_warning_shown_at
  end

  def test_check_browser__unlogged_in__to_be_deprecated
    assert_nil @request.session[:browser_warning_shown]

    @controller.stubs(:browser_supported_with_warning?).returns(true)
    @controller.stubs(:is_unsupported_browser?).returns(false)
    get :proper_action
    assert_response :success
    assert_false assigns[:invalid_browser]
    assert_equal true, assigns(:supported_with_warning_browser)
    assert_equal true, @request.session[:browser_warning_shown]
  end

  def test_check_browser__unlogged_in__to_be_deprecated__warning_shown
    @request.session[:browser_warning_shown] = true
    @controller.stubs(:browser_supported_with_warning?).returns(true)
    @controller.stubs(:is_unsupported_browser?).returns(false)
    @controller.expects(:set_browser_warning_content).once
    get :proper_action
    assert_response :success
    assert_false assigns[:invalid_browser]
    assert_equal true, assigns(:supported_with_warning_browser)
    assert_equal true, @request.session[:browser_warning_shown]
  end

  def test_login_using_mobile_auth_valid_case
    @current_member = nil
    @request.session[:member_id] = nil

    member = members(:f_admin)
    member.mobile_devices.create!(mobile_auth_token: "test", device_token: "token", platform: MobileDevice::Platform::IOS)
    assert_equal ['test'], member.reload.mobile_devices.collect(&:mobile_auth_token)
    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = 'test'
    @request.cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    MobileDevice.expects(:make_token).returns("abc")
    @controller.stubs(:is_mobile_app?).returns(true)
    @controller.stubs(:is_ios_app?).returns(true)

    current_program_is :albers
    get :proper_action

    assert_response :success
    assert_equal(users(:f_admin), assigns(:current_user))
    assert_equal 'abc', cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert_equal ['abc'], member.reload.mobile_devices.collect(&:mobile_auth_token)
  end

  def test_login_using_mobile_auth_invalid_case
    @current_member = nil
    @request.session[:member_id] = nil

    member = members(:f_admin)
    member.mobile_devices.create!(mobile_auth_token: "test", device_token: "token", platform: MobileDevice::Platform::IOS)
    assert_equal ['test'], member.reload.mobile_devices.collect(&:mobile_auth_token)
    cookie = ActionDispatch::Cookies::CookieJar.build(@request, @request.cookies)
    cookie.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = 'test'
    @request.cookies[MobileV2Constants::MOBILE_V2_AUTH_TOKEN] = cookie[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    MobileDevice.expects(:make_token).never
    @controller.stubs(:is_mobile_app?).returns(false)

    current_program_is :albers
    get :proper_action

    assert_response :redirect
    assert_nil assigns(:current_user)
    assert_equal 'test', cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert_equal ['test'], member.reload.mobile_devices.collect(&:mobile_auth_token)
  end

  def test_current_member_or_cookie
    @request.cookies[:uniq_token] = "something"
    assert_false ChronusAbExperiment.only_use_cookie
    @controller.stubs(:current_member).returns(nil)
    assert_equal "something", @controller.send(:current_member_or_cookie)

    @controller.stubs(:current_member).returns(Member.first)
    assert_equal Member.first.id, @controller.send(:current_member_or_cookie)

    ChronusAbExperiment.stubs(:only_use_cookie).returns(true)
    assert_equal "something", @controller.send(:current_member_or_cookie)
  end

  def test_current_user_or_wob_member
    @controller.stubs(:program_view?).returns(true)
    @controller.stubs(:current_user).returns("user")
    @controller.stubs(:current_member).never
    @controller.stubs(:wob_member).returns("wob_member")
    assert_equal "user", @controller.send(:current_user_or_wob_member)

    @controller.stubs(:program_view?).returns(false)
    assert_equal "wob_member", @controller.send(:current_user_or_wob_member)
  end

  def test_send_csv
    modify_const(:UTF8_BOM, "utf8-bom") do
      get :export
      assert_response :success
      assert_equal "text/csv; charset=iso-8859-1; header=present", @response.headers["Content-Type"]
      assert_equal "utf8-bomtest-data", @response.body
    end
  end

  def test_do_redirect
    current_program_is programs(:albers)
    get :do_redirect_action
    assert_redirected_to about_path
  end

  def test_do_redirect_ajax
    current_program_is programs(:albers)
    get :do_redirect_action, xhr: true
    assert_response :success
    assert_equal "window.location.href = \"#{about_path}\";", @response.body
  end

  def test_get_solution_pack_flash_message
    solution_pack = SolutionPack.new
    output = @controller.send(:get_solution_pack_flash_message, solution_pack, true)
    assert_equal ["The solution pack was imported and the  has been successfully setup! Please note that some invalid data in  model was deleted", :warning], output

    output = @controller.send(:get_solution_pack_flash_message, solution_pack, false)
    assert_equal ["The solution pack was imported and the  has been successfully setup!", :notice], output

    solution_pack.invalid_ck_assets_in = { "Resource" => [[1, 2], [3, 4]], "Page" => [[23, 34]] }
    output = @controller.send(:get_solution_pack_flash_message, solution_pack, false)
    assert_equal ["The solution pack was imported and the  has been successfully setup!<div class=\"font-bold\">Please handle the invalid attachment URLs (Old, New): Resource - [[1, 2], [3, 4]]; Page - [[23, 34]]</div>", :warning], output
  end

  def test_can_view_programs_listing_page
    @current_organization = programs(:org_foster)
    @controller.instance_variable_set(:@current_organization, @current_organization)
    assert @current_organization.standalone?
    assert_false @controller.send(:can_view_programs_listing_page?)

    @current_organization = programs(:org_primary)
    @controller.instance_variable_set(:@current_organization, @current_organization)
    @current_organization.programs.update_all(published: false)
    assert_false @controller.send(:can_view_programs_listing_page?)

    @current_organization.programs.update_all(published: true)

    @controller.expects(:logged_in_organization?).twice.returns(true)

    Organization.any_instance.expects(:programs_listing_visible_to_logged_in_users?).returns(true)
    assert @controller.send(:can_view_programs_listing_page?)

    Organization.any_instance.expects(:programs_listing_visible_to_logged_in_users?).returns(false)
    assert_false @controller.send(:can_view_programs_listing_page?)

    @controller.expects(:logged_in_organization?).twice.returns(false)

    Organization.any_instance.expects(:programs_listing_visible_to_all?).returns(true)
    assert @controller.send(:can_view_programs_listing_page?)

    Organization.any_instance.expects(:programs_listing_visible_to_all?).returns(false)
    assert_false @controller.send(:can_view_programs_listing_page?)
  end

  def test_track_activity_for_ei
    @controller.instance_variable_set(:@current_organization, "org")
    @controller.instance_variable_set(:@current_member, "member")
    @controller.stubs(:browser).returns('browser')
    @controller.stubs(:working_on_behalf?).returns(true)

    EngagementIndex.stubs(:enabled?).returns(true)
    ei = EngagementIndex.new('member', 'org', 'user', 'prog', 'browser', true)
    EngagementIndex.expects(:new).with("member", "org", nil, nil, 'browser', true).once.returns(ei)
    EngagementIndex.any_instance.expects(:save_activity!).with("activity", {something: "test"}).once.returns(nil)
    @controller.send(:track_activity_for_ei, "activity", {something: "test"})

    EngagementIndex.stubs(:enabled?).returns(false)
    EngagementIndex.expects(:new).never
    EngagementIndex.any_instance.expects(:save_activity!).never
    @controller.send(:track_activity_for_ei, "activity", {something: "test"})
  end

  def test_track_sessionless_activity_for_ei
    EngagementIndex.stubs(:enabled?).returns(true)
    ei = EngagementIndex.new('member', 'org', "user", nil, nil, false)
    EngagementIndex.expects(:new).with("member", "org", "user", nil, nil, false).once.returns(ei)
    EngagementIndex.any_instance.expects(:save_activity!).with("activity", {something: "test"}).once.returns(nil)
    @controller.send(:track_sessionless_activity_for_ei, "activity", "member", "org", {something: "test", user: "user"})

    EngagementIndex.stubs(:enabled?).returns(false)
    EngagementIndex.expects(:new).never
    EngagementIndex.any_instance.expects(:save_activity!).never
    @controller.send(:track_sessionless_activity_for_ei, "activity", "member", "org", {something: "test", user: "user", program: "program"})
  end

  def test_is_membership_form_enabled
    organization = programs(:org_primary)
    @controller.stubs(:super_console?).returns(false)

    enable_membership_request!(organization)
    assert @controller.send(:is_membership_form_enabled?, organization)

    disable_membership_request!(organization)
    assert_false @controller.send(:is_membership_form_enabled?, organization)
  end

  def test_super_user_or
    @controller.stubs(:super_console?).returns(true)
    assert @controller.send(:super_user_or?)
    @controller.stubs(:super_console?).returns(false)
    assert @controller.send(:super_user_or?) { true }
  end

  def test_handle_pending_profile_or_unanswered_required_qs_user_published
    current_user_is :f_mentor

    DummyApplicationController.any_instance.expects(:edit_member_path).with(members(:f_mentor), {ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING, landing_directly: true, first_visit: true}).never
    get :proper_action

    create_question(program: programs(:albers), question_type: ProfileQuestion::Type::TEXT, question_choices: "Abc, Def", role_names: [RoleConstants::MENTOR_NAME], required: true)
    get :proper_action
    assert_redirected_to program_root_path({hide_side_bar: true, unanswered_mandatory_prof_qs: true})
    assert assigns(:unanswered_mandatory_prof_qs)

    get :proper_action, params: { unanswered_mandatory_prof_qs: true}
    assert assigns(:unanswered_mandatory_prof_qs)

    Organization.any_instance.stubs(:amazon?).returns(true)
    get :proper_action, params: { unanswered_mandatory_prof_qs: true, error_raised: 1}
    assert assigns(:unanswered_mandatory_prof_qs)
    assert_equal "", flash[:error]
  end

  def test_handle_pending_profile_or_unanswered_required_qs_user_pending
    current_user_is :pending_user
    DummyApplicationController.any_instance.expects(:edit_member_path).with(members(:pending_user), {ei_src: EngagementIndex::Src::EditProfile::PROFILE_PENDING, landing_directly: true, first_visit: true}).once
    get :proper_action
  end

  def test_handle_set_mobile_auth_cookie
    member = members(:f_mentor)

    session["set_mobile_auth_cookie"] = true
    @controller.stubs(:is_mobile_app?).returns(true)
    @controller.stubs(:mobile_platform).returns(MobileDevice::Platform::IOS)
    MobileDevice.expects(:make_token).returns("abc")
    current_member_is member
    assert_difference "member.mobile_devices.count" do
      get :proper_action
    end
    assert_equal ["abc"], member.mobile_devices.pluck(:mobile_auth_token)
    assert_equal "abc", cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN]
    assert_nil session["set_mobile_auth_cookie"]
  end

  def test_handle_secondary_url
    organization = programs(:org_primary)
    default_program_domain = organization.default_program_domain
    program_domain = organization.program_domains.create(domain: "dummytest.com", subdomain: "dummytest", is_default: false)
    current_subdomain_is(program_domain.subdomain, program_domain.domain)
    get :proper_action
    assert_redirected_to "http://#{default_program_domain.subdomain}.#{default_program_domain.domain}/dummy_application/proper_action"
  end

  def test_configure_report_tab
    current_user_is :f_admin
    get :proper_action
    assert_response :success

    report_tab = @controller.tab_info["Reports"]
    sub_tabs = report_tab.subtabs
    assert_equal ["health_report", "outcome_report", "user_report"], sub_tabs["links_list"]
  end
end