require_relative './../../test_helper.rb'
class MeetingRequestsHelperTest < ActionView::TestCase
  def test_get_meeting_request_action_even_program_matching_by_mentee_alone
    chronus_s3_utils_stub
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    program = programs(:albers)
    program.update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_MENTOR)

    program_id = programs(:albers).id
    student = meeting_request.student
    mentor = meeting_request.mentor
    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME)
    set_response_text(action)
    assert_select "a[href=\"\/meeting_requests\/#{meeting_request.id}\/update_status\?filter=#{AbstractRequest::Filter::BY_ME}&program=#{program_id}&secret=#{student.member.calendar_api_key}&status=#{AbstractRequest::Status::WITHDRAWN}\"]", { text: 'Withdraw Request' }
    self.expects(:is_slot_expired?).never
    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME, skip_expiry_check: true)
    set_response_text(action)
    assert_select "a[href=\"\/meeting_requests\/#{meeting_request.id}\/update_status\?filter=#{AbstractRequest::Filter::BY_ME}&program=#{program_id}&secret=#{student.member.calendar_api_key}&status=#{AbstractRequest::Status::WITHDRAWN}\"]", { text: 'Withdraw Request' }
    self.expects(:is_slot_expired?).returns(false).at_least(0)
    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::ALL)
    set_response_text(action)
    assert_select "a[href=?]", 'javascript:void(0)', {text: 'Close Request'}

    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME, {accept_button: true, source: EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE})
    set_response_text(action)
    assert_select "a[href=\"\/meeting_requests\/#{meeting_request.id}\/update_status\?additional_info=#{EngagementIndex::Src::AcceptMeetingRequest::ACCEPT}&filter=#{AbstractRequest::Filter::TO_ME}&program=#{program_id}&secret=#{mentor.member.calendar_api_key}&src=#{EngagementIndex::Src::AcceptMentorRequest::USER_LISTING_PAGE}&status=#{AbstractRequest::Status::ACCEPTED}\"]", { text: 'Accept this time' }

    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME)
    set_response_text(action)
    assert_select 'a[href=?]', 'javascript:void(0)', { text: 'Decline request' }

    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
    actions = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::TO_ME)
    set_response_text(actions)
    assert_nil actions

    actions = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME)
    set_response_text(actions)
    assert_nil actions
  end

  def test_get_meeting_request_action_even_program_matching_by_admin
    chronus_s3_utils_stub
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    program = programs(:albers)
    program.update_attribute(:mentor_request_style, Program::MentorRequestStyle::MENTEE_TO_ADMIN)

    program_id = programs(:albers).id
    student = meeting_request.student
    mentor = meeting_request.mentor

    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME)
    set_response_text(action)
    assert_select "a[href='/meeting_requests/#{meeting_request.id}/update_status?filter=#{AbstractRequest::Filter::BY_ME}&program=#{program_id}&secret=#{student.member.calendar_api_key}&status=#{AbstractRequest::Status::WITHDRAWN}']", { text: 'Withdraw Request' }

    self.expects(:is_slot_expired?).never
    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME, skip_expiry_check: true)
    set_response_text(action)
    assert_select "a[href=\"\/meeting_requests\/#{meeting_request.id}\/update_status\?filter=#{AbstractRequest::Filter::BY_ME}&program=#{program_id}&secret=#{student.member.calendar_api_key}&status=#{AbstractRequest::Status::WITHDRAWN}\"]", { text: 'Withdraw Request' }
    self.expects(:is_slot_expired?).returns(false).at_least(0)
    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::ALL)
    set_response_text(action)
    assert_select "a[href=?]", 'javascript:void(0)', {text: 'Close Request'}

    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME, {accept_button: true})
    set_response_text(action)
    assert_select "a[href=\"\/meeting_requests\/#{meeting_request.id}\/update_status\?additional_info=#{EngagementIndex::Src::AcceptMeetingRequest::ACCEPT}&filter=#{AbstractRequest::Filter::TO_ME}&program=#{program_id}&secret=#{mentor.member.calendar_api_key}&src=&status=#{AbstractRequest::Status::ACCEPTED}\"]", { text: 'Accept this time' }

    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME)
    set_response_text(action)
    assert_select 'a[href=?]', 'javascript:void(0)', { text: 'Decline request' }

    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
    actions = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::TO_ME)
    assert_nil actions

    actions = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME)
    assert_nil actions
  end

  def test_get_meeting_request_action
    chronus_s3_utils_stub
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    program_id = programs(:albers).id
    student = meeting_request.student
    mentor = meeting_request.mentor

    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME)
    set_response_text(action)
    assert_select "a[href='/meeting_requests/#{meeting_request.id}/update_status?filter=#{AbstractRequest::Filter::BY_ME}&program=#{program_id}&secret=#{student.member.calendar_api_key}&status=#{AbstractRequest::Status::WITHDRAWN}']", { text: 'Withdraw Request' }
    self.expects(:is_slot_expired?).never
    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME, skip_expiry_check: true)
    set_response_text(action)
    assert_select "a[href=\"\/meeting_requests\/#{meeting_request.id}\/update_status\?filter=#{AbstractRequest::Filter::BY_ME}&program=#{program_id}&secret=#{student.member.calendar_api_key}&status=#{AbstractRequest::Status::WITHDRAWN}\"]", { text: 'Withdraw Request' }
    self.expects(:is_slot_expired?).returns(false).at_least(0)

    action = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::ALL)
    set_response_text(action)
    assert_select "a[href=?]", 'javascript:void(0)', {text: 'Close Request'}

    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME, {accept_button: true})
    set_response_text(action)
    assert_select "a[href=\"/meeting_requests/#{meeting_request.id}/update_status?additional_info=#{EngagementIndex::Src::AcceptMeetingRequest::ACCEPT}&filter=#{AbstractRequest::Filter::TO_ME}&program=#{program_id}&secret=#{mentor.member.calendar_api_key}&src=&status=#{AbstractRequest::Status::ACCEPTED}\"]", { text: 'Accept this time' }  

    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME)
    set_response_text(action)
    assert_select 'a[href=?]', 'javascript:void(0)', { text: 'Decline request' }

    self.expects(:is_slot_expired?).never
    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME, skip_expiry_check: true)
    set_response_text(action)
    assert_select 'a[href=?]', 'javascript:void(0)', { text: 'Decline request' }
    self.expects(:is_slot_expired?).returns(true)
    action = get_meeting_request_action(meeting_request, true, AbstractRequest::Filter::TO_ME, {accept_button: true})
    assert_nil action

    self.expects(:is_slot_expired?).returns(true)
    meeting_request.update_status!(users(:f_mentor), AbstractRequest::Status::ACCEPTED)
    actions = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::TO_ME)
    assert_nil actions

    self.expects(:is_slot_expired?).returns(true)
    actions = get_meeting_request_action(meeting_request, false, AbstractRequest::Filter::BY_ME)
    assert_nil actions
  end

  def test_get_meeting_request_acceptance_help_text
    chronus_s3_utils_stub
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = meeting.meeting_request
    meeting = meeting_request.get_meeting
    assert meeting.calendar_time_available?
    text = get_meeting_request_acceptance_help_text(meeting_request)
    assert_equal "(Optional) Leave a note for mkr_student madankumarrajan.", text
    meeting.update_attributes(calendar_time_available: false)
    text = get_meeting_request_acceptance_help_text(meeting_request)
    assert_equal "(Optional) Leave a note for mkr_student madankumarrajan. Make sure you mention date and times when you can connect.", text
  end

  def test_get_meeting_request_action_popup_id
    meeting = create_meeting(force_non_time_meeting: true)
    meeting_request = meeting.meeting_request

    assert_equal "modal_meeting_request_accept_link_#{meeting_request.id}", get_meeting_request_action_popup_id(meeting_request, AbstractRequest::Status::ACCEPTED)
    assert_equal "modal_meeting_request_reject_link_#{meeting_request.id}", get_meeting_request_action_popup_id(meeting_request, AbstractRequest::Status::REJECTED)
    assert_equal "modal_meeting_request_propose_link_#{meeting_request.id}", get_meeting_request_action_popup_id(meeting_request, AbstractRequest::Status::ACCEPTED, {propose_slot: true})
    assert_nil get_meeting_request_action_popup_id(meeting_request, AbstractRequest::Status::WITHDRAWN)
    assert_nil get_meeting_request_action_popup_id(meeting_request, AbstractRequest::Status::CLOSED)
  end

  def test_get_meeting_request_action_popup_and_popup_id
    meeting = create_meeting(force_non_time_meeting: true)
    meeting_request = meeting.meeting_request

    action_popup, action_popup_id = get_meeting_request_action_popup_and_popup_id([], meeting_request, AbstractRequest::Status::ACCEPTED)
    assert_equal "modal_meeting_request_accept_link_#{meeting_request.id}", action_popup_id
    assert_equal "meeting_requests/accept_popup", action_popup[:partial]
    assert_equal_hash({ meeting_request: meeting_request, is_mentor_action: true }, action_popup[:locals])

    action_popup, action_popup_id = get_meeting_request_action_popup_and_popup_id([], meeting_request, AbstractRequest::Status::REJECTED)
    assert_equal "modal_meeting_request_reject_link_#{meeting_request.id}", action_popup_id
    assert_equal "meeting_requests/reject_popup", action_popup[:partial]
    assert_equal_hash({ meeting_request: meeting_request, is_mentor_action: true, reject: true }, action_popup[:locals])

    action_popup, action_popup_id = get_meeting_request_action_popup_and_popup_id([meeting_request], meeting_request, AbstractRequest::Status::ACCEPTED)
    assert_equal "modal_meeting_request_accept_link_#{meeting_request.id}", action_popup_id
    assert_nil action_popup

    action_popup, action_popup_id = get_meeting_request_action_popup_and_popup_id([meeting_request], meeting_request, AbstractRequest::Status::REJECTED)
    assert_equal "modal_meeting_request_reject_link_#{meeting_request.id}", action_popup_id
    assert_nil action_popup

    action_popup, action_popup_id = get_meeting_request_action_popup_and_popup_id([], meeting_request, AbstractRequest::Status::WITHDRAWN)
    assert_nil action_popup_id
    assert_nil action_popup
  end

  def test_is_slot_expired
    chronus_s3_utils_stub
    time = 2.days.from_now
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_false is_slot_expired?(meeting, {})
    time_traveller(3.days.ago) do
      time = 1.days.from_now
      meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    end
    assert is_slot_expired?(meeting, {})
    meeting_request = create_meeting_request
    proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    assert_false is_slot_expired?(meeting, {slot: proposed_slot})
    time_traveller(3.days.ago) do
      meeting_request = create_meeting_request
      proposed_slot = create_meeting_proposed_slot({meeting_request_id: meeting_request.id})
    end
    assert is_slot_expired?(meeting, {slot: proposed_slot})
  end

  def test_get_tabs_for_meeting_requests_listing
    label_tab_mapping = {
      "Pending" => AbstractRequest::Filter::ACTIVE,
      "Accepted" => AbstractRequest::Filter::ACCEPTED,
      "Declined" => AbstractRequest::Filter::REJECTED,
      "Withdrawn" => AbstractRequest::Filter::WITHDRAWN,
      "Closed" => AbstractRequest::Filter::CLOSED
    }
    active_tab = AbstractRequest::Filter::ACTIVE
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: manage_meeting_requests_path, param_name: :list)
    get_tabs_for_meeting_requests_listing(active_tab)
  end

  private

  def _meeting
    "meeting"
  end

  def _Meeting
    "Meeting"
  end

end