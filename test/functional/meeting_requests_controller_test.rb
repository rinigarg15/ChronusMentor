require_relative './../test_helper.rb'

class MeetingRequestsControllerTest < ActionController::TestCase
  def setup
    super
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC, false)
    members(:f_mentor).update_attributes!(will_set_availability_slots: true)
    MeetingRequest.destroy_all
    chronus_s3_utils_stub
  end

  def test_should_check_feature_enabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    current_user_is :f_mentor
    assert_permission_denied { get :index }
  end

  def test_check_permissions
    current_user_is :f_admin
    assert_permission_denied { get :index }
  end

  def test_index_for_admin_all
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    assert_permission_denied { get :index, params: { filter: :all }}
  end

  def test_index_for_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { src: "quick_links", sort_field: 'id', sort_order: 'asc'}
    assert_response :success
    assert_equal "id", assigns(:filter_params)[:sort_field]
    assert_equal "asc", assigns(:filter_params)[:sort_order]
    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert_false assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
    assert_equal "quick_links", assigns(:source)
  end

  def test_index_when_accept_and_propose_id_is_set
    time = 2.days.from_now
    meetings = []
    15.times { |i| meetings << create_meeting(topic: "m#{i}", force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes) }
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    meeting = meetings[1]
    get :index, params: { email_meeting_request_id: "#{meeting.meeting_request_id}", email_action: MeetingRequestsController::EmailAction::ACCEPT_AND_PROPOSE} # second page
    assert_equal "#{meeting.meeting_request_id}", assigns(:email_meeting_request_id)
    assert_equal MeetingRequestsController::EmailAction::ACCEPT_AND_PROPOSE, assigns(:email_action)
    assert assigns(:meeting_requests).include?(meeting.meeting_request)
  end

  def test_index_when_reject_id_is_set
    time = 2.days.from_now
    meetings = []
    15.times { |i| meetings << create_meeting(topic: "m#{i}", force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes) }
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    meeting = meetings[1]
    get :index, params: { email_meeting_request_id: "#{meeting.meeting_request_id}", email_action: MeetingRequestsController::EmailAction::DECLINE} # second page
    assert_equal "#{meeting.meeting_request_id}", assigns(:email_meeting_request_id)
    assert_equal MeetingRequestsController::EmailAction::DECLINE, assigns(:email_action)
    assert assigns(:meeting_requests).include?(meeting.meeting_request)
  end

  def test_index_for_mentor_all
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all}
    assert_response :success
    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert_false assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_student
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index
    assert_response :success
    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_student_all
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all}
    assert_response :success
    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_student_by_me
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :by_me}
    assert_response :success
    assert_equal AbstractRequest::Filter::BY_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [], assigns(:meeting_requests)
    assert_equal "Sent Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_student_to_me
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :me}
    assert_response :success
    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_student_filter_wrong
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :wrong}
    assert_response :success
    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all_even_program_matching_by_mentee_alone
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    program.update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    get :index, params: { filter: :all}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all_pending
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all, list: :active}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all_pending_even_program_matching_by_mentee_alone
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    program.update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)
    get :index, params: { filter: :all, list: :active}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all_accepted
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all, list: :accepted}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "accepted", assigns(:status_type)
    assert_equal [], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all_declined
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all, list: :rejected}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "rejected", assigns(:status_type)
    assert_equal [], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_admin_all_withdrawn
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all, list: :withdrawn}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "withdrawn", assigns(:status_type)
    assert_equal [], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_mentor_withdrawn_permission_denied
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true

    assert_permission_denied do
      get :index, params: { filter: :all, list: :withdrawn}
    end
  end

  def test_index_permission_denied_with_wrong_param
    current_user_is :f_admin
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true

    assert_permission_denied do
      get :index, params: { filter: :all, list: :something}
    end
  end

  def test_index_for_mentor_admin_all_closed
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:f_mentor).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :f_mentor
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.calendar_setting.update_attribute :allow_mentor_to_configure_availability_slots, true
    get :index, params: { filter: :all, list: :closed}
    assert_response :success
    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "closed", assigns(:status_type)
    assert_equal [], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_index_for_will_set_availability_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    current_user_is :f_mentor
    members(:f_mentor).update_attributes!(will_set_availability_slots: false)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    programs(:albers).calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)

    get :index, params: { meeting_request_id: meeting_request.id, meeting_request_status: AbstractRequest::Status::REJECTED}
    assert_response :success

    assert_equal AbstractRequest::Filter::TO_ME, assigns(:filter_field)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting_request], assigns(:meeting_requests)
    assert_equal "Received Meeting Requests", assigns(:title)
    assert_equal meeting_request, assigns(:meeting_request)
    assert_equal AbstractRequest::Status::REJECTED, assigns(:meeting_request_status)
  end

  def test_index_for_student
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    current_user_is :mkr_student
    users(:mkr_student).program.calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    get :index, params: { meeting_request_id: meeting_request.id, meeting_request_status: AbstractRequest::Status::ACCEPTED}
    assert_response :success

    assert_equal AbstractRequest::Filter::BY_ME, assigns(:filter_field)
    assert_false assigns(:with_bulk_actions)
    assert_false assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting_request], assigns(:meeting_requests)
    assert_equal "Sent Meeting Requests", assigns(:title)
    assert_nil assigns(:meeting_request)
    assert_nil assigns(:meeting_request_status)
  end

  def test_index_for_student_all
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_user_is :mkr_student
    users(:mkr_student).program.calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    get :index, params: { filter: :all}
    assert_response :success

    assert_equal AbstractRequest::Filter::BY_ME, assigns(:filter_field)
    assert_equal "active", assigns(:status_type)
    assert_false assigns(:with_bulk_actions)
    assert_false assigns(:allow_multi_view)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "Sent Meeting Requests", assigns(:title)
  end

  def test_index_for_student_admin_all
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    users(:mkr_student).promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    current_user_is :mkr_student
    users(:mkr_student).program.calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    get :index, params: { filter: :all}
    assert_response :success

    assert_equal AbstractRequest::Filter::ALL, assigns(:filter_field)
    assert assigns(:with_bulk_actions)
    assert assigns(:allow_multi_view)
    assert_equal "active", assigns(:status_type)
    assert_equal [meeting.meeting_request], assigns(:meeting_requests)
    assert_equal "All Meeting Requests", assigns(:title)
  end

  def test_propose_slot_popup
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    get :propose_slot_popup, params: { id: meeting_request.id}
    assert_response :success
    assert_equal meeting_request.id, assigns(:meeting_request).id
  end

  def test_update_status_invalid_id
    user = users(:f_student)

    current_program_is user.program
    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT
    
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_student)
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST, member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).never
    assert_nothing_raised do
      get :update_status, params: { id: 0, status: AbstractRequest::Status::ACCEPTED, additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT, src: src, secret: user.member.calendar_api_key, meeting_request: { acceptance_message: "Meet me at 5:30 today" }}
    end
    assert_equal "The request you are trying to access does not exist.", flash[:error]
    assert_redirected_to program_root_path
  end

  def test_update_status_as_accepted_permission_denied
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    receiver_member = meeting_request.mentor.member
    assert meeting_request.active?

    current_user_is meeting_request.student
    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = meeting_request.student
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST, member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).never
    assert_permission_denied do
      get :update_status, params: { id: meeting_request.id, status: AbstractRequest::Status::ACCEPTED,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: src, secret: receiver_member.calendar_api_key, meeting_request: { acceptance_message: "Meet me at 5:30 today" }}
    end
  end

  def test_update_status_as_withdrawn_permission_denied
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    sender_member = meeting_request.student.member
    assert meeting_request.active?

    current_user_is meeting_request.mentor
    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = meeting_request.mentor
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST, member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).never
    assert_permission_denied do
      get :update_status, params: { id: meeting_request.id, status: AbstractRequest::Status::WITHDRAWN,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: src, secret: sender_member.calendar_api_key}
    end
  end

  def test_get_flash_for_rejection
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request1 = meeting.meeting_request
    User.any_instance.stubs(:get_meeting_limit_to_reset).returns(3)
    users(:f_mentor).user_setting.update_attributes(max_meeting_slots: 5)

    post :reject_with_notes, params: { id: meeting_request1.id, status: AbstractRequest::Status::REJECTED, :meeting_request => { response_text: "Sorry I wont come " , rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }}
    assert_equal "Thank you for your response. #{meeting.mentee.name} has been notified. Your meeting limit per calendar month is updated to make sure you don't receive any new requests. You can always update your limit under your <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=max_meeting_slots_#{programs(:albers).id}\">profile settings</a>.", flash[:notice]
    meeting_request1.reload
    assert assigns(:limit_updated)
    assert_equal AbstractRequest::Rejection_type::REACHED_LIMIT, meeting_request1.rejection_type
  end

  def test_get_flash_for_rejection_with_matching_reason
    current_program_is programs(:albers)
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request1 = meeting.meeting_request
    post :reject_with_notes, params: { id: meeting_request1.id, status: AbstractRequest::Status::REJECTED, :meeting_request => { response_text: "Sorry I wont come " , rejection_type: AbstractRequest::Rejection_type::MATCHING }}
    assert_equal flash[:notice], "Thank you for your response. #{meeting.mentee.name} has been notified."
    meeting_request1.reload
    assert_nil assigns(:limit_updated)
    assert_equal AbstractRequest::Rejection_type::MATCHING, meeting_request1.rejection_type
  end

  def test_update_status_accept_from_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
    meeting_request = meeting.meeting_request
    member = members(:f_mentor)
    
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.not_responded?
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    current_user_is :f_mentor
    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_PROPOSE_SLOT
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program
    assert_nil meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).once
    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key, additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_PROPOSE_SLOT, src: src}
    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)
    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
    assert assigns(:create_scrap)
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
    scrap = Scrap.last
    assert_equal 'Your request for a meeting is accepted. The meeting time was confirmed.', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_no_difference "Scrap.count" do
      get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key, additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_PROPOSE_SLOT, src: src}
    end
  end

  def test_update_status_mentor_accepting_proposed_slot
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
    member = members(:f_mentor)
    
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.not_responded?
    current_user_is :f_mentor

    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program
    assert_nil meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MeetingRequest, [meeting_request.id, meeting_request.id]).once
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Not(equals(MeetingRequest)), kind_of(Array)).at_least(0)

    assert_difference 'Scrap.count',1 do
      get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key, slot_id: proposed_slot.id,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT, src: src}
    end
    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)

    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
    assert_nil meeting_request.reload.acceptance_message
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source
    scrap = Scrap.last
    assert_equal 'Your request for a meeting is accepted. The meeting time was confirmed.', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_equal "Meeting", scrap.ref_obj_type
    assert_equal members(:f_mentor), scrap.sender
    assert_equal [members(:mkr_student)], scrap.receivers
    assert_false member_meeting.meeting.program.calendar_sync_enabled?
    assert_equal members(:mkr_student).get_valid_time_zone, meeting_request.meeting.time_zone
  end

  def test_update_status_mentor_accepting_proposed_slot_with_calendar_sync
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC, true)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    member = members(:f_mentor)
    
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.not_responded?
    current_user_is :f_mentor

    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)

    assert_difference 'Scrap.count',1 do
      get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key, slot_id: proposed_slot.id}
    end
    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)

    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
    assert_nil meeting_request.reload.acceptance_message
    scrap = Scrap.last
    assert_equal 'Your request for a meeting is accepted. The meeting time was confirmed.', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_equal "Meeting", scrap.ref_obj_type
    assert_equal members(:f_mentor), scrap.sender
    assert_equal [members(:mkr_student)], scrap.receivers
    assert member_meeting.meeting.program.calendar_sync_enabled?
  end

  def test_update_status_mentor_accepting_meeting_with_message
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source

    member = members(:f_mentor)
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.not_responded?
    current_user_is :f_mentor

    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})

    src = EngagementIndex::Src::AccessFlashMeetingArea::EMAIL
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).once

    assert_difference 'Scrap.count',1 do
      get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, secret: member.calendar_api_key, acceptanceMessage: "I am available on friday",  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: src}
    end
    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)

    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
    assert_nil meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source
    assert_equal [MemberMeeting::ATTENDING::YES], meeting.reload.member_meetings.pluck(:attending).uniq
    assert_equal "I am available on friday", meeting_request.reload.acceptance_message
    scrap = Scrap.last
    assert_equal 'Your request for a meeting is accepted. The meeting time was not set. I am available on friday', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_equal "Meeting", scrap.ref_obj_type
    assert_equal members(:f_mentor), scrap.sender
    assert_equal [members(:mkr_student)], scrap.receivers
  end

  def test_update_status_mentor_accepting_meeting_by_proposing_slot
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
    member = members(:f_mentor)
    
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.not_responded?
    current_user_is :f_mentor

    student_member_meeting = meeting.member_meetings.where(:member_id => members(:mkr_student).id).first

    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)

    src = EngagementIndex::Src::AcceptMentorRequest::MENTOR_REQUEST_LISTING_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).once

    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      assert_difference 'Scrap.count',1 do
        get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: src, secret: member.calendar_api_key, proposedSlot: {date: "December 26, 2100", location: "Hyd", startTime: "5:00 am", endTime: "5:30 am"}, slotMessage: "I am also available on friday"}
      end
    end
    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)

    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, student_member_meeting.reload.attending
    assert_equal "I am also available on friday", meeting_request.acceptance_message
    assert_equal "2100-12-26 05:00:00 +0000".to_datetime, meeting_request.reload.meeting.start_time
    assert_equal "2100-12-26 05:30:00 +0000".to_datetime, meeting_request.reload.meeting.end_time
    scrap = Scrap.last
    assert_equal 'Your request for a meeting is accepted. The meeting time was updated. I am also available on friday', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_equal "Meeting", scrap.ref_obj_type
    assert_equal members(:f_mentor), scrap.sender
    assert_equal [members(:mkr_student)], scrap.receivers
    assert_false member_meeting.meeting.program.calendar_sync_enabled?
    assert_equal members(:f_mentor).get_valid_time_zone, meeting_request.meeting.time_zone
  end

  def test_update_status_withdrawn_from_mentee
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    assert meeting.active?
    meeting_request = meeting.meeting_request
    member = members(:mkr_student)
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.accepted?
    current_user_is :mkr_student
    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::WITHDRAWN, filter: AbstractRequest::Filter::BY_ME, secret: member.calendar_api_key }
    assert_redirected_to meeting_requests_path

    assert_false meeting.reload.active?
    assert meeting_request.reload.withdrawn?
    assert_equal "The meeting request has been withdrawn", flash[:notice]
  end

  def test_update_with_unlogged_in_invalid_secret_key
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    current_program_is programs(:albers)

    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::WITHDRAWN, filter: AbstractRequest::Filter::BY_ME, secret: "manju", src: "email"}
    assert_redirected_to program_root_path
  end

  def test_update_with_unlogged_in_valid_secret_key
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    member = members(:f_mentor)
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.active?
    assert member_meeting.not_responded?
    current_program_is programs(:albers)
    src = EngagementIndex::Src::AccessFlashMeetingArea::EMAIL
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_PROPOSE_SLOT
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).once
    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_PROPOSE_SLOT, src: src}

    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
  end

  def test_update_with_already_updated_status
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    member = members(:f_mentor)
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    assert meeting_request.accepted?
    assert member_meeting.accepted?
    current_program_is programs(:albers)

    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).never
    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE}

    assert meeting_request.reload.accepted?
    assert member_meeting.reload.accepted?
    assert_equal "The meeting request has already been accepted", flash[:error]
  end

  def test_update_with_already_updated_withdrawn_status
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::WITHDRAWN)
    current_program_is programs(:albers)

    src = EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = users(:f_mentor)
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).never
    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, filter: AbstractRequest::Filter::TO_ME, secret: member.calendar_api_key,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE}

    assert meeting_request.reload.withdrawn?
    assert_equal "The meeting request has already been withdrawn", flash[:error]
  end

  def test_update_status_from_email_non_logged_in_scenario
    program = programs(:albers)
    current_program_is program
    self.stubs(:current_user).returns(nil)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time + 30.minutes, end_time: time + 60.minutes, owner_id: members(:mkr_student).id)
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
    meeting_request = meeting.meeting_request
    receiver_member = meeting_request.mentor.member
    src = EngagementIndex::Src::AccessFlashMeetingArea::EMAIL
    get :update_status, params: { id: meeting_request.id, program: program.id, status: AbstractRequest::Status::ACCEPTED, secret: receiver_member.calendar_api_key, additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT, src: src }
    meeting_count = meeting_request.mentor.get_meeting_slots_booked_in_the_month(time)
    assert_equal "You are successfully connected. For "+DateTime.localize(time, format: :month_year)+", you have #{meeting_count} meetings scheduled and cannot accept requests for more. <a href=\"/p/albers/members/3/edit?focus_settings_tab=true&amp;scroll_to=max_meeting_slots_#{program.id}\">Change</a>", flash[:notice]
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
  end

  def test_update_status_from_email
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    receiver_member = meeting_request.mentor.member
    assert meeting_request.active?

    current_user_is meeting_request.mentor
    src = EngagementIndex::Src::AccessFlashMeetingArea::EMAIL
    additional_info = EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    user = meeting_request.mentor
    member = user.member
    program = user.program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::ACCEPT_MEETING_REQUEST,member, member.organization, {:context_place => src, context_object: additional_info, user: member.user_in_program(program), program: program, browser: browser}).once
    get :update_status, params: { id: meeting_request.id, program: programs(:albers).id, status: AbstractRequest::Status::ACCEPTED, secret: receiver_member.calendar_api_key,  additional_info: EngagementIndex::Src::AcceptMeetingRequest::ACCEPT_AND_SEND_MESSAGE, src: src}
    assert_redirected_to meeting_path(meeting, current_occurrence_time: meeting.occurrences.first.start_time.in_time_zone(Time.zone), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)
  end

  def test_new_login_required
    current_program_is programs(:albers)

    get :new
    assert_redirected_to new_session_path
  end

  def test_new_invalid_mentor_request_id
    current_user_is users(:f_mentor)
    get :new, params: { mentor_request_id: 0 }

    assert_response :success
    assert_equal "The request you are trying to access does not exist.", flash[:error]
    assert_template "common/_redirect_to"
  end

  def test_new_checks_if_request_type_change_is_allowed
    current_user_is users(:f_mentor)
    MentorRequest.any_instance.expects(:can_convert_to_meeting_request?).returns(false)

    assert_permission_denied do
      get :new, params: { mentor_request_id: mentor_requests(:mentor_request_0).id }
    end
  end

  def test_new_when_request_type_change_is_allowed_and_mentor_opting_meeting
    mentor_request = mentor_requests(:mentor_request_0)
    MentorRequest.any_instance.expects(:can_convert_to_meeting_request?).returns(true)
    current_user_is users(:f_mentor)

    get :new, params: { mentor_request_id: mentor_request.id }
    assert_response :success
    assert_template "meeting_requests/_propose_slot_popup"
    assert_equal mentor_request.student, assigns[:meeting_request].student
    assert_equal mentor_request.mentor, assigns[:meeting_request].mentor
  end

  def test_create_login_required
    current_program_is programs(:albers)

    get :create
    assert_redirected_to new_session_path
  end

  def test_create_with_invalid_secret_key
    current_user_is users(:f_mentor)

    get :create, params: { secret: "manju" }
    assert_redirected_to program_root_path
  end

  def test_create_invalid_mentor_request_id
    user = users(:f_mentor)
    current_user_is user

    get :create, params: { secret: user.member.calendar_api_key, mentor_request_id: 0 }

    assert_response :success
    assert_equal "The request you are trying to access does not exist.", flash[:error]
    assert_template "common/_redirect_to"
  end

  def test_create_invalid_mentor_request_id
    user = users(:f_mentor)
    current_user_is user

    get :create, params: { format: :js, secret: user.member.calendar_api_key, mentor_request_id: 0 }

    assert_response :success
    assert_equal "The request you are trying to access does not exist.", flash[:error]
    assert_equal %Q[window.location.href = "#{mentor_requests_path}";], response.body
  end

  def test_create_checks_if_request_type_change_is_allowed
    mentor_request = mentor_requests(:mentor_request_0)
    user = users(:f_mentor)
    current_user_is user
    MentorRequest.any_instance.expects(:can_convert_to_meeting_request?).returns(false)

    assert_permission_denied do
      get :create, params: { mentor_request_id: mentor_request.id, secret: user.member.calendar_api_key }
    end
  end

  def test_create_with_acceptance_message
    mentor_request = mentor_requests(:mentor_request_0)
    MentorRequest.any_instance.expects(:can_convert_to_meeting_request?).returns(true)

    member = members(:f_mentor)
    current_user_is :f_mentor

    assert_difference "Meeting.count" do
      assert_difference "MeetingRequest.count" do
        assert_difference 'Scrap.count', 1 do
          assert_difference "MentorRequest.count", -1 do
            get :create, params: { mentor_request_id: mentor_request.id, secret: member.calendar_api_key, acceptanceMessage: "I am available on friday" }
          end
        end
      end
    end

    meeting = Meeting.last
    meeting_request = MeetingRequest.last
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first

    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)

    assert meeting_request.reload.accepted?
    assert meeting_request.allow_request_type_change_from_mentor_to_meeting?
    assert member_meeting.reload.accepted?
    assert_nil meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source
    assert_equal [MemberMeeting::ATTENDING::YES], meeting.reload.member_meetings.pluck(:attending).uniq
    assert_equal "I am available on friday", meeting_request.reload.acceptance_message
    scrap = Scrap.last
    assert_equal 'I am available on friday', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_equal "Meeting", scrap.ref_obj_type
    assert_equal members(:f_mentor), scrap.sender
    assert_equal [mentor_request.student.member], scrap.receivers
  end

    def test_create_meeting_by_proposing_slot
    mentor_request = mentor_requests(:mentor_request_0)
    MentorRequest.any_instance.expects(:can_convert_to_meeting_request?).returns(true)

    member = members(:f_mentor)
    student = mentor_request.student
    current_user_is :f_mentor

    assert_difference "Meeting.count" do
      assert_difference "MeetingRequest.count" do
        assert_difference 'Scrap.count', 1 do
          assert_difference "ActionMailer::Base.deliveries.size", 2 do
            assert_difference "MentorRequest.count", -1 do
              get :create, params: { mentor_request_id: mentor_request.id, secret: member.calendar_api_key,  proposedSlot: {date: "December 26, 2100", location: "Hyd", startTime: "5:00 am", endTime: "5:30 am"}, slotMessage: "I am also available on friday"}
            end
          end
        end
      end
    end

    meeting = Meeting.last
    meeting_request = MeetingRequest.last
    member_meeting = member.member_meetings.where(meeting_id: meeting.id).first
    student_member_meeting = meeting.member_meetings.where(member_id: student.member_id).first

    assert_redirected_to meeting_path(meeting, current_occurrence_time: assigns(:occurrence_time), ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE)

    assert meeting_request.accepted?
    assert meeting_request.allow_request_type_change_from_mentor_to_meeting?
    assert member_meeting.accepted?
    assert_false assigns[:meeting_request].skip_email_notification
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: member.id).rsvp_change_source
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, student_member_meeting.reload.attending
    assert_equal "I am also available on friday", meeting_request.acceptance_message
    assert_equal "2100-12-26 05:00:00 +0000".to_datetime, meeting_request.reload.meeting.start_time
    assert_equal "2100-12-26 05:30:00 +0000".to_datetime, meeting_request.reload.meeting.end_time
    scrap = Scrap.last
    assert_equal 'I am also available on friday', scrap.content
    assert_equal 'Good unique name has accepted your request for a meeting!', Scrap.last.subject
    assert_equal "Meeting", scrap.ref_obj_type
    assert_equal members(:f_mentor), scrap.sender
    assert_equal [student.member], scrap.receivers
    assert_false member_meeting.meeting.program.calendar_sync_enabled?
    assert_equal members(:f_mentor).get_valid_time_zone, meeting_request.meeting.time_zone
  end

  def test_create_meeting_by_proposing_slot_with_invalid_date
    mentor_request = mentor_requests(:mentor_request_0)
    MentorRequest.any_instance.expects(:can_convert_to_meeting_request?).returns(true)
    member = members(:f_mentor)
    student = mentor_request.student
    current_user_is :f_mentor

    assert_no_difference "Meeting.count" do
      assert_no_difference "MeetingRequest.count" do
        assert_no_difference 'Scrap.count'do
          assert_no_difference "ActionMailer::Base.deliveries.size" do
            assert_no_difference "MentorRequest.count" do
              get :create, xhr: true, params: { mentor_request_id: mentor_request.id, secret: member.calendar_api_key,  proposedSlot: {date: "December 26, 2000", location: "Hyd", startTime: "5:00 am", endTime: "5:30 am"}, slotMessage: "I am also available on friday"}
            end
          end
        end
      end
    end

    assert_response :success
    assert_equal "The meeting could not be created", flash[:error]
  end

  def test_manage_meeting_requests_access_for_mentor
    current_user_is :f_mentor

    assert_permission_denied do 
      get :manage
    end
  end

  def test_manage_meeting_requests_login_required
    current_program_is programs(:albers)

    get :manage
    assert_redirected_to new_session_path
  end

  def test_manage_meeting_requests_access_for_admin_with_no_results
    current_user_is :f_admin

    get :manage, params: { sort_field: 'id', sort_order: 'asc'}
    assert_response :success

    assert_equal "id", assigns(:filter_params)[:sort_field]
    assert_equal "asc", assigns(:filter_params)[:sort_order]
    assert_equal assigns(:from_date_range), programs(:albers).created_at.to_date
    assert_equal assigns(:to_date_range), Time.current.to_date
    assert_tab(TabConstants::MANAGE)
    assert_page_title("Meeting Requests")
    assert_equal [], assigns(:meeting_requests)
    assert_select "#results_pane", text: /There are no meeting requests matching the chosen criteria/
  end

  def test_manage_meeting_requests_with_date_filter
    current_user_is :f_admin

    m1 = create_meeting_request(:mentor => users(:f_mentor), :student => users(:f_student), :status => AbstractRequest::Status::ACCEPTED)
    m1.update_attributes!(created_at: "Thu, 2 Jan 2017".to_datetime.utc)

    get :manage, params: { list: "accepted", filters: {"date_range"=>"12/20/2016 - 07/27/2017"}}
    assert_response :success

    assert_equal assigns(:from_date_range), "20/12/2016".to_date
    assert_equal assigns(:to_date_range), "27/07/2017".to_date
    assert_tab(TabConstants::MANAGE)
    assert_page_title("Meeting Requests")
    assert_equal [m1], assigns(:meeting_requests)
  end

  def test_meeting_requests_view_title
    current_user_is :f_admin
    program = programs(:albers)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_MEETING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending meeting requests", abstract_view_id: view.id)

    get :manage, params: { :metric_id => metric.id}
    assert_response :success

    assert_not_nil assigns(:metric)
    assert_page_title(metric.title)
  end

  def test_manage_with_src
    current_user_is :f_admin
    get :manage, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_manage_no_src
    current_user_is :f_admin
    get :manage
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_manage_meeting_requests_access_for_admin_with_results
    current_user_is :f_admin
    time = 2.days.from_now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2.update_attributes!(status: AbstractRequest::Status::ACCEPTED)

    get :manage
    assert_response :success

    assert_tab(TabConstants::MANAGE)
    assert_page_title("Meeting Requests")
    assert assigns(:is_manage_view)
    assert assigns(:with_bulk_actions)
    assert_false assigns(:meeting_requests).include?(meeting_request2)
    assert_equal [meeting_request1], assigns(:meeting_requests)
  end

  def test_manage_meeting_requests_access_for_admin_with_accepted_results
    current_user_is :f_admin
    time = 2.days.from_now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request3 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    meeting_request3.update_attributes!(status: AbstractRequest::Status::ACCEPTED)

    get :manage, params: { list: "accepted"}
    assert_response :success

    assert_tab(TabConstants::MANAGE)
    assert_page_title("Meeting Requests")
    assert assigns(:is_manage_view)
    assert_false assigns(:with_bulk_actions)
    assert_false assigns(:meeting_requests).include?(meeting_request1)
    assert_equal [meeting_request3, meeting_request2], assigns(:meeting_requests)
  end

  def test_manage_meeting_requests_access_for_admin_with_sent_between_applied
    current_user_is :f_admin
    time = 2.days.from_now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request3 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request1.update_attributes!(created_at: DateTime.new(2010))
    meeting_request2.update_attributes!(created_at: DateTime.new(2000))
    meeting_request3.update_attributes!(created_at: DateTime.new(1990))

    get :manage, params: { list: "active", filters: {"date_range"=> "01/01/1995 - 10/23/2015"}}
    assert_response :success

    assert_tab(TabConstants::MANAGE)
    assert_page_title("Meeting Requests")
    assert_equal_unordered [meeting_request1, meeting_request2], assigns(:meeting_requests)
  end

  def test_manage_with_alert_id
    current_user_is :f_admin
    program = programs(:albers)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_MEETING_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending meeting requests", abstract_view_id: view.id)
    alert_params = {target: 20, description: "alert description", operator: Report::Alert::OperatorType::LESS_THAN, filter_params: {cjs_alert_filter_params_0: {name: FilterUtils::MeetingRequestViewFilters::FILTERS.first[1][:value], operator: FilterUtils::DateRange::IN_LAST, value: "10"}}.to_yaml.gsub(/--- \n/, "")}

    alert = create_alert_for_metric(metric, alert_params)

    get :manage, params: { :metric_id => metric.id, :abstract_view_id => view.id, :alert_id => alert.id}
    assert_response :success
    assert assigns(:params_with_abstract_view_params)[:search_filters][FilterUtils::MeetingRequestViewFilters::SENT_BETWEEN].present?

    get :manage, params: { :metric_id => metric.id, :abstract_view_id => view.id}
    assert_response :success
    assert assigns(:params_with_abstract_view_params)[:search_filters].nil?
  end

  def test_csv_export_for_manage_meeting_requests_with_active_requests
    time = Time.now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request3 = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request    
    current_user_is users(:f_admin)
    
    get :manage, params: { format: :csv}
    assert_response :success

    assert_equal 3, assigns(:meeting_requests).size
    csv_response = @response.body.split("\n")
    assert_equal 4, csv_response.size
    assert_match /pending_meeting_requests.+\.csv/, @response.header["Content-disposition"]
    assert_equal 'text/csv', @response.header["Content-Type"]
  end

  def test_csv_export_for_manage_meeting_requests_with_accepted_requests
    time = Time.now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request3 = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request    
    meeting_request2.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    meeting_request3.update_attributes!(status: AbstractRequest::Status::ACCEPTED)
    current_user_is users(:f_admin)
    
    get :manage, params: { format: :csv, list: "accepted"}
    assert_response :success

    assert_equal 2, assigns(:meeting_requests).size
    assert_equal [meeting_request3, meeting_request2], assigns(:meeting_requests)
    csv_response = @response.body.split("\n")
    assert_equal 3, csv_response.size
    assert_match /accepted_meeting_requests.+\.csv/, @response.header["Content-disposition"]
    assert_equal 'text/csv', @response.header["Content-Type"]
  end

  def test_csv_withdrawn_export
    time = Time.now
    meeting_request1 = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request2 = create_meeting(force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes).meeting_request
    meeting_request1.update_attributes!(status: AbstractRequest::Status::WITHDRAWN)
    meeting_request2.update_attributes!(status: AbstractRequest::Status::WITHDRAWN)
    current_user_is users(:f_admin)
    get :manage, params: { format: :csv, list: "withdrawn"}
    assert_response :success

    assert_equal 2, assigns(:meeting_requests).size
    assert_equal [meeting_request2, meeting_request1], assigns(:meeting_requests)
    csv_response = @response.body.split("\n")
    assert_equal 3, csv_response.size # CSV header + 2 withdrawn requests
    assert_match /withdrawn_meeting_requests.+\.csv/, @response.header["Content-disposition"]
    assert_equal 'text/csv', @response.header["Content-Type"]
  end

  def test_get_filtered_meeting_requests
    program = programs(:albers)
    time = Time.now.utc + 2.days
    
    MeetingRequestsFilterService.any_instance.stubs(:get_filtered_meeting_request_ids).returns([[32,33], [34,35]])
    MeetingRequestsFilterService.any_instance.stubs(:current_program).returns(program)

    @controller.send(:get_filtered_meeting_requests)

    assert_equal assigns(:percentage), 0
    assert_equal assigns(:prev_periods_count), 2

    MeetingRequestsFilterService.any_instance.stubs(:get_filtered_meeting_request_ids).returns([[33], [32,34]])
    @controller.send(:get_filtered_meeting_requests)

    assert_equal assigns(:percentage), -50
    assert_equal assigns(:prev_periods_count), 2
  end

  def test_manage_scoped_meeting_requests
    program = programs(:albers)

    @controller.send(:get_scoped_meeting_requests, program.meeting_requests)
    assert_equal_hash( {
      active_meeting_requests: [],
      accepted_meeting_requests: [],
      rejected_meeting_requests: [],
      withdrawn_meeting_requests: [],
      closed_meeting_requests: [],
      all_meeting_requests: []
    }, assigns(:meeting_request_hash))

    m1 = create_meeting_request(mentor: users(:f_mentor), student: users(:f_student), status: AbstractRequest::Status::ACCEPTED)
    m2 = create_meeting_request(mentor: users(:ram), student: users(:f_mentor_student), status: AbstractRequest::Status::NOT_ANSWERED)
    m3 = create_meeting_request(mentor: users(:robert), student: users(:rahim), status: AbstractRequest::Status::WITHDRAWN)
    m4 = create_meeting_request(mentor: users(:robert), student: users(:rahim), status: AbstractRequest::Status::CLOSED)
    m5 = create_meeting_request(mentor: users(:f_mentor), student: users(:mkr_student), status: AbstractRequest::Status::REJECTED)
    m6 = create_meeting_request(mentor: users(:f_mentor_student), student: users(:mkr_student), status: AbstractRequest::Status::NOT_ANSWERED)

    @controller.send(:get_scoped_meeting_requests, program.meeting_requests.reload)
    assert_equal [m1], assigns(:meeting_request_hash)[:accepted_meeting_requests]
    assert_equal [m5], assigns(:meeting_request_hash)[:rejected_meeting_requests]
    assert_equal [m3], assigns(:meeting_request_hash)[:withdrawn_meeting_requests]
    assert_equal [m4], assigns(:meeting_request_hash)[:closed_meeting_requests]
    assert_equal_unordered [m2, m6], assigns(:meeting_request_hash)[:active_meeting_requests]
    assert_equal_unordered [m1, m2, m3, m4, m5, m6], assigns(:meeting_request_hash)[:all_meeting_requests]
  end

  def test_select_all_ids_permission_denied
    current_user_is :moderated_mentor
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_no_filter_params
    current_user_is :f_admin
    active_requests = programs(:albers).meeting_requests.active

    get :select_all_ids
    assert_response :success
    assert_equal 'active', assigns(:status_type)
    assert_equal ({list: nil, date_range: nil, sort_field: "id", sort_order: "desc"}), assigns(:filter_params)
    assert_equal active_requests, assigns(:meeting_requests)
    assert_equal_unordered active_requests.collect(&:id).map(&:to_s), JSON.parse(response.body)["meeting_request_ids"]
    assert_equal_unordered active_requests.collect(&:sender_id), JSON.parse(response.body)["sender_ids"]
    assert_equal_unordered active_requests.collect(&:receiver_id), JSON.parse(response.body)["receiver_ids"]
  end

  def test_select_all_ids_sort_by_oldest
    current_user_is :f_admin
    active_requests = programs(:albers).meeting_requests.active.order(id: 'asc')
    get :select_all_ids, params: { sort_order: 'asc'}
    assert_response :success
    assert_equal 'active', assigns(:status_type)
    assert_equal ({list: nil, date_range: nil, sort_field: "id", sort_order: "asc"}), assigns(:filter_params)
    assert_equal active_requests, assigns(:meeting_requests)
  end

  def test_select_all_ids_active
    current_user_is :f_admin
    active_requests = programs(:albers).meeting_requests.active

    get :select_all_ids, params: { :list => 'active'}
    assert_response :success
    assert_equal 'active', assigns(:status_type)
    assert_equal ({list: "active", date_range: nil, sort_field: "id", sort_order: "desc"}), assigns(:filter_params)
    assert_equal_unordered active_requests, assigns(:meeting_requests)
    assert_equal_unordered active_requests.collect(&:id).map(&:to_s), JSON.parse(response.body)["meeting_request_ids"]
    assert_equal_unordered active_requests.collect(&:sender_id), JSON.parse(response.body)["sender_ids"]
    assert_equal_unordered active_requests.collect(&:receiver_id), JSON.parse(response.body)["receiver_ids"]
  end

  def test_reject_with_notes_invalid_id
    current_user_is users(:f_mentor)
    post :reject_with_notes, params: { id: 0, status: AbstractRequest::Status::REJECTED}
    assert_equal "The request you are trying to access does not exist.", flash[:error]
    assert_redirected_to meeting_requests_path
  end

  def test_reject_with_notes_login_required_in_program
    current_program_is programs(:albers)
    meeting_request = create_meeting_request
    post :reject_with_notes, params: { id: meeting_request.id, status: AbstractRequest::Status::REJECTED}
    assert_redirected_to new_session_path
  end

  def test_reject_with_notes_check_authorization_current_user_not_a_mentor
    current_program_is programs(:albers)
    current_user_is :f_student
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert programs(:albers).calendar_enabled?
    assert_false users(:f_student).is_mentor?
    assert_permission_denied { post :reject_with_notes, params: { id: meeting_request.id, status: AbstractRequest::Status::REJECTED }}
  end

  def test_reject_with_notes_check_authorization_calendar_not_enabled
    programs(:albers).enable_feature(FeatureName::CALENDAR, false)
    current_program_is programs(:albers)
    current_user_is :f_mentor_student
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert_false programs(:albers).calendar_enabled?
    assert_permission_denied{ post :reject_with_notes, params: { id: meeting_request.id, status: AbstractRequest::Status::REJECTED }}
  end

  def test_reject_with_notes_check_authorization_current_user_is_not_the_meeting_requests_receiver
    current_program_is programs(:albers)
    current_user_is :f_mentor_student
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request = meeting.meeting_request
    assert programs(:albers).calendar_enabled?
    assert users(:f_mentor_student).is_mentor?
    assert_false meeting_request.mentor.id == users(:f_mentor_student).id
    assert_permission_denied { post :reject_with_notes, params: { id: meeting_request.id, status: AbstractRequest::Status::REJECTED }}
  end

  def test_reject_with_notes
    current_program_is programs(:albers)
    current_user_is :f_mentor
    user = users(:f_mentor)
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request1 = meeting.meeting_request
    assert programs(:albers).calendar_enabled?
    assert users(:f_mentor).is_mentor?
    assert meeting_request1.mentor.id == users(:f_mentor).id
    slot_filled_current_month = user.get_meeting_slots_booked_in_the_month(Time.now)
    slot_filled_next_month = user.get_meeting_slots_booked_in_the_month(Time.now.next_month)
    user.user_setting.update_attributes(max_meeting_slots: [slot_filled_current_month, slot_filled_next_month].max+5)
    post :reject_with_notes, params: { id: meeting_request1.id, status: AbstractRequest::Status::REJECTED, :meeting_request => { response_text: "Sorry I wont come " , rejection_type: AbstractRequest::Rejection_type::REACHED_LIMIT }}
    user.reload
    user.user_setting.reload
    assert_equal user.user_setting.max_meeting_slots, [slot_filled_current_month, slot_filled_next_month].max
    assert_equal meeting_request1, assigns(:meeting_request)
    assert assigns(:limit_updated)
    assert_equal AbstractRequest::Status::REJECTED, meeting_request1.reload.status
    assert_equal "Sorry I wont come ", meeting_request1.response_text
    assert meeting_request1.reload.rejected?
    assert_redirected_to meeting_requests_path
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal meeting_request1.student.email, delivered_email.to[0]
    assert_match "Sorry I wont come", get_text_part_from(delivered_email)
    meeting_request1.reload
    assert_equal AbstractRequest::Rejection_type::REACHED_LIMIT, meeting_request1.rejection_type
  end

  def test_reject_request_from_user_profile_page
    session[:last_visit_url] = '/'
    current_program_is programs(:albers)
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request1 = meeting.meeting_request
    post :reject_with_notes, params: { id: meeting_request1.id, status: AbstractRequest::Status::REJECTED, :meeting_request => { response_text: "Sorry I wont come ", rejection_type: AbstractRequest::Rejection_type::OTHERS }, src: EngagementIndex::Src::AcceptMentorRequest::USER_PROFILE_PAGE}
    assert_redirected_to '/'
    meeting_request1.reload
    assert_equal AbstractRequest::Rejection_type::OTHERS, meeting_request1.rejection_type
  end

  def test_reject_request_from_user_listing_page
    session[:last_visit_url] = '/'
    current_program_is programs(:albers)
    current_user_is :f_mentor
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, owner_id: members(:mkr_student).id)
    meeting_request1 = meeting.meeting_request
    post :reject_with_notes, params: { id: meeting_request1.id, status: AbstractRequest::Status::REJECTED, :meeting_request => { response_text: "Sorry I wont come ", rejection_type: AbstractRequest::Rejection_type::BUSY }, src: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}
    assert_redirected_to '/'
    meeting_request1.reload
    assert_equal AbstractRequest::Rejection_type::BUSY, meeting_request1.rejection_type
  end

  def test_select_all_ids_not_admin
    current_user_is :f_mentor
    assert_permission_denied { get :select_all_ids }
  end

  def test_close_meeting_request
    ChronusElasticsearch.skip_es_index = false
    Timecop.freeze(Time.now) do
      meeting_requests = []
      meeting_requests << create_meeting_request
      meeting_requests << create_meeting_request(mentor: users(:mentor_0), student: users(:student_0), status: AbstractRequest::Status::ACCEPTED)
      meeting_requests << create_meeting_request(mentor: users(:mentor_1), student: users(:student_1), status: AbstractRequest::Status::REJECTED)
      meeting_requests << create_meeting_request(mentor: users(:mentor_2), student: users(:student_2), status: AbstractRequest::Status::WITHDRAWN)
      closed_meeting_request = create_meeting_request(mentor: users(:mentor_3), student: users(:student_3))
      closed_meeting_request.close_request!
      meeting_requests << closed_meeting_request

      # Active Meeting Requests will be closed and only first meeting request is active
      DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(MeetingRequest, [meeting_requests[0].id])
      admin = users(:f_admin)
      current_user_is admin
      assert_emails 2 do
        post :update_bulk_actions, xhr: true, params: { bulk_actions: { request_type: AbstractRequest::Status::CLOSED,
          meeting_request_ids: meeting_requests.collect(&:id).join(" ") }, meeting_request: { response_text: "Sorry" }, sender: true
        }
      end
      assert_equal "The selected 2 meeting requests have been closed", assigns(:notice)
      recently_closed_meeting_request = meeting_requests[0].reload
      assert_equal "Sorry", recently_closed_meeting_request.response_text
      assert_equal AbstractRequest::Status::CLOSED, meeting_requests[0].status
      assert_equal AbstractRequest::Status::ACCEPTED, meeting_requests[1].reload.status
      assert_equal AbstractRequest::Status::REJECTED, meeting_requests[2].reload.status
      assert_equal AbstractRequest::Status::WITHDRAWN, meeting_requests[3].reload.status
      assert_equal AbstractRequest::Status::CLOSED, meeting_requests[4].reload.status
      assert_equal admin, recently_closed_meeting_request.closed_by
      assert_equal Time.now.utc.to_s, recently_closed_meeting_request.closed_at.utc.to_s
    end
    ChronusElasticsearch.skip_es_index = true
  end

  def test_close_meeting_request_only_by_admin
    current_user_is :f_mentor

    meeting_request = create_meeting_request

    assert_permission_denied  do
      post :update_bulk_actions, xhr: true, params: { :bulk_actions => {:request_type => AbstractRequest::Status::CLOSED, :meeting_request_ids => [meeting_request.id]}, :meeting_request => {:response_text => "Sorry"}, :sender => true}
    end
  end

  def test_handle_reply_via_email_for_meeting_request_accepted_emails
    meeting_request = create_meeting_request(:mentor => users(:f_mentor), :student => users(:mkr_student), :status => AbstractRequest::Status::ACCEPTED)
    meeting = meeting_request.meeting
    email_params = {obj_type: ReplyViaEmail::MEETING_REQUEST_ACCEPTED_CALENDAR, original_sender_member: members(:f_mentor), subject: "test subject", content: "test content" }
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
    end
    #non calendar meeting
    email_params = {obj_type: ReplyViaEmail::MEETING_REQUEST_ACCEPTED_NON_CALENDAR, original_sender_member: members(:f_mentor), subject: "test subject", content: "test content" }
    assert_difference 'Scrap.count',1 do
      assert meeting.member_meetings.find_by(member_id: members(:mkr_student).id).handle_reply_via_email(email_params)
      assert_equal 'test content', Scrap.last.content
      assert_equal 'test subject', Scrap.last.subject
      assert_equal "Meeting", Scrap.last.ref_obj_type
    end
  end

  private

  def get_new_browser
    Browser.new(request.headers["User-Agent"], accept_language: request.headers["Accept-Language"])
  end

end