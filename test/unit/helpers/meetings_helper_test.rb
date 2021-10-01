require_relative './../../test_helper.rb'
require_relative "./../../../app/helpers/meetings_helper"

class MeetingsHelperTest < ActionView::TestCase

  def test_meeting_duration
    m = meetings(:f_mentor_mkr_student)
    t = m.start_time
    assert_equal "(30 min)", meeting_duration(m)

    schedule = m.schedule
    schedule.duration = 60.minutes
    m.update_attribute(:schedule, schedule)
    assert_equal "(1 hr)", meeting_duration(m)

    schedule = m.schedule
    schedule.duration = 90.minutes
    m.update_attribute(:schedule, schedule)
    assert_equal "(1.5 hrs)", meeting_duration(m)
  end

  def test_get_valid_times
    m = meetings(:f_mentor_mkr_student)
    m.update_attributes(:start_time => "2011-02-26 07:30:00", :end_time => "2011-02-26 09:30:00")
    st_time, en_time = get_valid_times(m.reload, 2.hours, 30)
    assert_equal ["07:30 am", "08:00 am", "08:30 am", "09:00 am"], st_time
    assert_equal ["08:00 am", "08:30 am", "09:00 am", "09:30 am"], en_time

    m.update_attributes(:start_time => "2011-02-26 05:30:00", :end_time => "2011-02-26 09:30:00")
    st_time, en_time = get_valid_times(m.reload, 4.hours, 30)
    assert_equal ["05:30 am", "06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am", "08:30 am", "09:00 am"], st_time
    assert_equal ["06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am", "08:30 am", "09:00 am", "09:30 am"], en_time

    m.update_attributes(:start_time => "2011-02-26 00:30:00", :end_time => "2011-02-26 01:30:00")
    st_time, en_time = get_valid_times(m.reload, 1.hours, 30)
    assert_equal ["12:30 am", "01:00 am"], st_time
    assert_equal ["01:00 am", "01:30 am"], en_time
  end

  def test_get_choose_time_label_key
    program = programs(:albers)

    program.stubs(:enhanced_meeting_scheduler_enabled?).returns(true)
    assert_equal "available_slots_with_zone", get_choose_time_label_key(program: program)
    assert_equal "available_slots_with_zone", get_choose_time_label_key(program: program, force_value: true)
    assert_equal "pick_a_time_with_zone", get_choose_time_label_key(program: program, force_value: false)
    
    program.stubs(:enhanced_meeting_scheduler_enabled?).returns(false)
    assert_equal "pick_a_time_with_zone", get_choose_time_label_key(program: program)
    assert_equal "available_slots_with_zone", get_choose_time_label_key(program: program, force_value: true)
    assert_equal "pick_a_time_with_zone", get_choose_time_label_key(program: program, force_value: false)
    
    assert_equal "pick_a_time_with_zone", get_choose_time_label_key
  end

  def test_get_valid_times_for_60_minutes
    m = meetings(:f_mentor_mkr_student)
    m.update_attributes(:start_time => "2011-02-26 07:30:00", :end_time => "2011-02-26 09:30:00")
    st_time, en_time = get_valid_times(m.reload, 2.hours, 60)
    assert_equal ["07:30 am", "08:00 am", "08:30 am"], st_time
    assert_equal ["08:30 am", "09:00 am", "09:30 am"], en_time
  end

  def test_is_next_day
    next_day_arr = is_next_day?("10:30 pm", "03:00 am", "11:30 pm", "12:30 am", 30)
    assert next_day_arr[0]
    assert_false next_day_arr[1]
    assert next_day_arr[2]
  end

  def test_get_meeting_html_id
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_attributes(:start_time => "2011-02-26 07:30:00", :end_time => "2011-02-26 09:30:00")
    hsh = Meeting.recurrent_meetings([meeting], get_merged_list: true)[0]
    assert_equal "meeting_#{hsh[:meeting].id}_#{hsh[:current_occurrence_time].to_i}", get_meeting_html_id(hsh)
  end

  def test_get_meeting_accept_message
    current_user = users(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)
    current_time = meeting.occurrences.first
    meeting_count = current_user.get_meeting_slots_booked_in_the_month(current_time)
    self.stubs(:_meetings).returns("meetings")
    assert_equal get_meeting_accept_message(meeting, meeting_count, current_time, true, current_user), "<div class=\"text-center text-muted\" style=\"font-weight:bold\">For "+DateTime.localize(current_time, format: :month_year).to_s+", you have "+meeting_count.to_s+" meetings scheduled and cannot accept requests for more. <a href=\"/members/3/edit?focus_settings_tab=true&amp;scroll_to=max_meeting_slots_#{current_user.program_id}\">Change</a></div>"
    current_user.user_setting.max_meeting_slots = 6
    meeting_count = current_user.user_setting.max_meeting_slots - 1
    assert_equal get_meeting_accept_message(meeting, meeting_count, current_time, true, current_user), "<div class=\"text-center text-muted\" style=\"font-weight:bold\">For "+DateTime.localize(current_time, format: :month_year).to_s+", you have "+meeting_count.to_s+" meetings scheduled and can accept requests for "+1.to_s+" more. <a href=\"/members/3/edit?focus_settings_tab=true&amp;scroll_to=max_meeting_slots_#{current_user.program_id}\">Change</a></div>"
    assert_equal get_meeting_accept_message(meeting, meeting_count, current_time, false, current_user), "For "+DateTime.localize(current_time, format: :month_year).to_s+", you have "+meeting_count.to_s+" meetings scheduled and can accept requests for "+1.to_s+" more. <a href=\"/members/3/edit?focus_settings_tab=true&amp;scroll_to=max_meeting_slots_#{current_user.program_id}\">Change</a>"

    #When there is no limit on max meetings
    UserSetting.any_instance.stubs(:max_meeting_slots).returns(nil)
    assert_equal get_meeting_accept_message(meeting, 3, current_time, true, current_user), "<div class=\"text-center text-muted\" style=\"font-weight:bold\"></div>"
  end

  def test_get_attendee_name_and_rsvp_info
    name_content = "Freakin Admin"
    rsvp_html = get_icon_content("fa-lg fa fa-check-circle text-navy")
    attendee = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)

    self.stubs(:get_skype_icon_for_attendee).with(attendee, meeting).returns("<span>Skype</span>".html_safe)

    result = get_attendee_name_and_rsvp_info(name_content, rsvp_html, false, attendee, meeting)
    set_response_text(result)

    assert_select "div.media-body" do
      assert_select "div.m-t-xxs" do
        assert_select "span", :text => "#{name_content}"
        assert_select "span.p-l-xxs" do
          assert_select "i.fa.fa-check-circle.text-navy"
        end
      end
    end

    result = get_attendee_name_and_rsvp_info(name_content, rsvp_html, true, attendee, meeting)

    assert_select_helper_function_block "div.media-body", result do
      assert_select "div.m-t-xxs" do
        assert_select "span", :text => "#{name_content}"
        assert_select "span", :text => "Skype"
        assert_select "span.small" do
          assert_select "i.fa.fa-check-circle.text-navy"
        end
      end
    end
  end

  def test_get_x_minute_meeting_text
    program = programs(:albers)
    program.stubs(:get_calendar_slot_time).returns(1000)
    assert_equal "1000 minute", get_x_minute_meeting_text(program)
  end

  def test_get_skype_icon_for_attendee
    attendee = members(:f_mentor)
    user = users(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)

    self.expects(:wob_member).at_least(0).returns(members(:mkr_student))

    assert_nil user.skype_id
    content = get_skype_icon_for_attendee(attendee, meeting)
    assert_no_match /"skype"/, content

    skype_question = programs(:org_primary).profile_questions.skype_question.first
    ans = ProfileAnswer.create!(:profile_question => skype_question, :ref_obj => members(:f_mentor), :answer_text => '')
    ans.update_attribute :answer_text, 'vikram.venkat'

    content = get_skype_icon_for_attendee(attendee, meeting)
    assert_match "href=\"skype:vikram.venkat?call\">", content

    programs(:org_primary).enable_feature(FeatureName::SKYPE_INTERACTION, false)

    content = get_skype_icon_for_attendee(attendee, meeting)
    assert_no_match /"skype"/, content

    content = get_skype_icon_for_attendee(nil, meeting)
    assert_no_match /"skype"/, content

    ans = ProfileAnswer.create!(:profile_question => skype_question, :ref_obj => members(:mkr_student), :answer_text => '')
    ans.update_attribute :answer_text, 'mkr.student'

    content = get_skype_icon_for_attendee(members(:mkr_student), meeting)
    assert_no_match /"skype"/, content

    Member.any_instance.stubs(:user_in_program).returns(nil)

    content = get_skype_icon_for_attendee(attendee, meeting)
    assert_no_match /"skype"/, content

    self.expects(:wob_member).at_least(0).returns(members(:f_admin))

    Member.any_instance.unstub(:user_in_program)

    ans = ProfileAnswer.create!(:profile_question => skype_question, :ref_obj => members(:f_admin), :answer_text => '')
    ans.update_attribute :answer_text, 'f.admin'

    content = get_skype_icon_for_attendee(members(:f_admin), meeting)
    assert_no_match /"skype"/, content
  end

  def test_meeting_attendees_for_display
    meeting = meetings(:psg_mentor_psg_student)
    mentor = members(:psg_mentor1)
    student = members(:psg_student1)
    content = meeting_attendees_for_display(meeting, meeting.start_time)
    assert_match /#{student.name}/, content
    assert_match /#{mentor.name}/, content

    student.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)
    assert_false student.reload.is_attending?(meeting.reload, meeting.start_time)
    mentor.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)
    content1 = meeting_attendees_for_display(meeting.reload, meeting.start_time)
    assert_match /#{student.name}/, content1
    assert_match /Declined/, content1
    assert_match get_icon_content("fa-lg fa fa-times-circle text-danger"), content1
    assert_no_match /confirmed/, content1
    assert_no_match /responded/, content1

    student.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::YES)
    assert student.reload.is_attending?(meeting.reload, meeting.start_time)
    content2 = meeting_attendees_for_display(meeting, meeting.start_time)
    assert_match /#{student.name}/, content2
    assert_match /Confirmed/, content2
    assert_match /#{mentor.name}/, content2
    assert_no_match /declined/, content2
    assert_no_match /responded/, content2

    student.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO_RESPONSE)
    assert_false student.reload.is_attending?(meeting.reload, meeting.start_time)
    content3 = meeting_attendees_for_display(meeting, meeting.start_time)
    assert_match /#{student.name}/, content3
    assert_match /Responded/, content3
    assert_match /#{mentor.name}/, content3
    assert_no_match /declined/, content3
    assert_no_match /confirmed/, content3

    # Meeting with user removed
    mem_meeting = meeting.member_meetings.where(member_id: meeting.owner.id).first
    mem_meeting.destroy
    meeting.update_attributes({owner: nil, group: nil})
    result = meeting_attendees_for_display(meeting, meeting.start_time)
    set_response_text(result)
    assert_select "div.p-b-xxs" do
      assert_select "div.media-left" do
        assert_select "img.img-circle[src=?][width=?][height=?]", "/assets/v3/user_small.jpg", "21", "21"
      end
      assert_select "div.media-body" do
        assert_select "span", text: "Removed User"
      end
    end
  end

  def test_meeting_attendees_for_display_with_see_more
    meeting = meetings(:psg_mentor_psg_student)
    group = meeting.group
    meeting.update_attributes(members: group.members.map(&:member))
    set_response_text meeting_attendees_for_display(meeting, meeting.start_time)

    assert_select "div.font-bold", text: "Attendees (#{group.members.count})"
    assert_select "div.media-left", count: group.members.count - MeetingsHelper::SEE_MORE_LIMIT
    assert_select "a.small.font-bold.p-l-lg[data-target=\"#all_attendees_#{meeting.id}\"]", text: "See All"
  end

  def test_get_all_attendees_modal_footer
    assert_select_helper_function "a.btn-sm.btn-white", get_all_attendees_modal_footer, text: "Close"
  end

  def test_render_meeting_location_details
    meeting = meetings(:f_mentor_mkr_student)
    member = members(:f_mentor)
    member_meeting = meeting.member_meetings.find_by(member_id: member.id)

    meeting.update_attribute(:location, "Hyderabad")

    result = render_meeting_location_details(meeting, member)
    set_response_text(result)
    assert_select "div.media-left.p-r-0" do
      assert_select "i.fa.fa-map-marker"
    end
    assert_select "div.media-body", :text => "Hyderabad"

    result = render_meeting_location_details(meeting, member, {meeting_area: true})
    set_response_text(result)
    assert_select "i.fa.fa-map-marker"

    meeting.update_attribute(:location, nil)
    Meeting.any_instance.stubs(:location_can_be_set_by_member?).returns(true)

    result = render_meeting_location_details(meeting, member, {meeting_area: true})
    set_response_text(result)
    meeting_id = get_meeting_html_id({meeting: meeting, current_occurrence_time: nil})
    assert_select "i.fa-map-marker.m-t-xs.m-r-md"
    assert_select "a.cjs_set_meeting_location_#{meeting_id}.btn.btn-xs.btn-white.text-muted", :text => "Set Location"
    assert_select "a[data-url=\"#{edit_meeting_path(meeting, show_recurring_options: meeting.recurrent?, current_occurrence_time: nil, set_meeting_time: true, set_meeting_location: true, meeting_area: true, from_connection_home_page_widget: nil)}\"]"
    assert_select "a[href=\"javascript:void(0)\"]", :text => "Set Location"

    Meeting.any_instance.stubs(:location_can_be_set_by_member?).returns(false)

    result = render_meeting_location_details(meeting, member, {meeting_area: true})
    set_response_text(result)

    assert_select "i.fa-map-marker.m-r-md"
    assert_select "span.text-muted", :text => "No location specified"

    member.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)

    result = render_meeting_location_details(meeting, member, {meeting_area: true})
    set_response_text(result)

    assert_select "i.fa-map-marker.m-r-md"
    assert_select "span.text-muted", :text => "No location specified"
  end

  def test_get_member_response_icon_for_meeting
    meeting = meetings(:psg_mentor_psg_student)
    student = members(:psg_student1)

    member_meeting = meeting.member_meetings.find_by(member_id: student.id)

    student.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO)

    result = get_member_response_icon_for_meeting(student.reload, meeting.reload, meeting.start_time)
    set_response_text(result)
    assert_select "i.fa.fa-times-circle.text-danger"

    student.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::NO_RESPONSE)
    result = get_member_response_icon_for_meeting(student.reload, meeting.reload, meeting.start_time)
    set_response_text(result)
    assert_select "i.fa.fa-question-circle.text-muted"

    student.mark_attending!(meeting, attending: MemberMeeting::ATTENDING::YES)
    result = get_member_response_icon_for_meeting(student.reload, meeting.reload, meeting.start_time)
    set_response_text(result)
    assert_select "i.fa.fa-check-circle.text-navy"
  end

  def test_get_user_image_and_name
    meeting = meetings(:f_mentor_mkr_student)

    user_image, user_name = get_user_image_and_name(meeting: meeting, meeting_area: true)

    assert_equal "  <div class=\"media  small  \">\n    <div class=\" media-middle\">\n      <a href=\"/members/#{meeting.owner_id}\"><div id=\"\" class=\"image_with_initial inline image_with_initial_dimensions_small profile-picture-white_and_grey profile-font-styles table-bordered thick-border img-circle img-circle \" title=\"Good unique name\">GN</div></a>\n    </div>\n  </div>\n", user_image
    assert_equal "<span><a class=\"nickname\" title=\"#{meeting.owner.name}\" href=\"/members/#{meeting.owner_id}\">#{meeting.owner.name}</a></span>", user_name

    meeting.owner = nil

    user_image, user_name = get_user_image_and_name(meeting: meeting, meeting_area: true)
    assert_equal "<img class=\"img-circle\" src=\"/assets/v3/user_small.jpg\" alt=\"User small\" width=\"35\" height=\"35\" />", user_image
    assert_blank user_name

    user_image, user_name = get_user_image_and_name(removed_user: true)
    assert_equal "<img class=\"img-circle\" src=\"/assets/v3/user_small.jpg\" alt=\"User small\" width=\"21\" height=\"21\" />", user_image
    assert_equal "Removed User", user_name
  end

  def test_get_response_with_icon_class_for_RSVP
    response = MemberMeeting::ATTENDING::YES
    content1 = get_response_with_icon_class_for_RSVP(response)
    assert_match /Confirmed/, content1
    assert_match /fa fa-fw fa-check/, content1

    response = MemberMeeting::ATTENDING::NO
    content2 = get_response_with_icon_class_for_RSVP(response)
    assert_match /Declined/, content2
    assert_match /fa fa-ban/, content2

    response = MemberMeeting::ATTENDING::NO_RESPONSE
    content3 = get_response_with_icon_class_for_RSVP(response)
    assert_match /Not Responded/, content3
    assert_no_match /fa fa-ban/, content3
    assert_no_match /fa fa-fw fa-check/, content3
  end

  def test_attendee_image_size
    meeting_area = true
    size = attendee_image_size(meeting_area)
    assert_equal size, "35x35" 

    meeting_area = false
    size = attendee_image_size(meeting_area)
    assert_equal size, "21x21"
  end
  
  def test_get_members_with_links
    program = programs(:albers)
    member = members(:mkr_student)
    
    mentoring_session_object = Meeting.first
    users_string = get_members_with_links(mentoring_session_object)
    assert users_string.match(/mkr_student/).present?
    assert users_string.match(/Good unique name/).present?
    assert_false users_string.match(/How was your overall meeting experience?/).present?
    assert_false users_string.match(/Why was the meeting cancelled?/).present?

    users_string = get_members_with_links(mentoring_session_object)
    assert users_string.match(/mkr_student/).present?
    assert users_string.match(/Good unique name/).present?
    assert_false users_string.match(/How was your overall meeting experience?/).present?
    assert_false users_string.match(/How was your meeting with your/).present?

    user = members(:mkr_student).user_in_program(programs(:albers))
    user.destroy
    users_string = get_members_with_links(mentoring_session_object)

    assert_false users_string.match(/mkr_student/).present?
    assert users_string.match(/Good unique name/).present?
    assert users_string.match(/Removed\ User/).present?
  end  

  def test_get_member_pictures_with_links
    program = programs(:albers)
    mentor_survey = program.get_meeting_feedback_survey_for_role(RoleConstants::MENTOR_NAME)
    mentee_survey = program.get_meeting_feedback_survey_for_role(RoleConstants::STUDENT_NAME)
    member = members(:f_mentor)
    survey_question = create_survey_question({:program => program, allow_other_option: true, :question_type => CommonQuestion::Type::SINGLE_CHOICE, :question_choices => "get,set,go", :survey => mentee_survey})
    sa = SurveyAnswer.create!({user: users(:mkr_student), response_id: 10001, :answer_value => {answer_text: "get", question: survey_question}, last_answered_at: Time.now, survey_id: mentee_survey.id, survey_question: survey_question})
    
    users_string = get_member_pictures_with_links(meetings(:f_mentor_mkr_student), member, mentor_survey.survey_questions, {})
    assert users_string.match(/Good unique name/).present?
    assert_false users_string.match(/How was your overall meeting experience?/).present?
    assert_false users_string.match(/Why was the meeting cancelled?/).present?
     
    member = members(:mkr_student)
    users_string = get_member_pictures_with_links(meetings(:f_mentor_mkr_student), member, mentee_survey.survey_questions, {users(:mkr_student).id => [sa]})
    assert users_string.match(/mkr_student/).present?
    assert_false users_string.match(/Good unique name/).present?
    assert_false users_string.match(/How was your overall meeting experience?/).present?
    assert_false users_string.match(/How was your meeting with your/).present?

    user = members(:mkr_student).user_in_program(programs(:albers))
    user.destroy
    users_string = get_member_pictures_with_links(meetings(:f_mentor_mkr_student), members(:mkr_student).reload, mentee_survey.survey_questions, {})
    assert_false users_string.match(/mkr_student/).present?
    assert_select_helper_function "img[alt='User small']", users_string
  end

  def test_get_sync_calendar_instructions
    content = get_sync_calendar_instructions
    assert_equal "<a target=\"_blank\" href=\"https://chronus-mentor-assets.s3.amazonaws.com/global-assets/files/Steps_for_syncing_Mentoring_Calendar_with_Email_Clients_V2.pdf\">Click here</a> to view detailed instructions on syncing your calendar with other popular calendars.", content
  end

  def test_time_to_calendar_date_format
    time = Time.new(2002, 10, 31, 2, 2, 2, "+05:30")
    formatted_time = time_to_calendar_date_format(time)
    assert_equal "October 31, 2002", formatted_time
  end

  def test_is_meeting_notification_enabled
    program = programs(:albers)
    member = members(:f_mentor)
    time = 4.weeks.ago.change(:usec => 0)
    meeting = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    member_meeting = meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    mailer_accepted_calendar = program.mailer_templates.enabled.last
    MeetingRequestStatusAcceptedNotification.stubs(:mailer_attributes).returns(mailer_accepted_calendar)
    assert is_meeting_notification_enabled(meeting)
    mailer_accepted_calendar.update_attribute(:enabled, false)
    assert_false is_meeting_notification_enabled(meeting)

    #checking for non calendar meeting
    meeting.update_attribute(:calendar_time_available, false)
    mailer_accepted_non_calendar = program.mailer_templates.enabled.last
    MeetingRequestStatusAcceptedNotificationNonCalendar.stubs(:mailer_attributes).returns(mailer_accepted_non_calendar)
    assert is_meeting_notification_enabled(meeting)
    mailer_accepted_non_calendar.update_attribute(:enabled, false)
    assert_false is_meeting_notification_enabled(meeting)
  end

  def test_get_updated_status
    program = programs(:albers)
    member = members(:f_mentor)
    time = 4.weeks.ago.change(:usec => 0)
    meeting = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    member_meeting = meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    status = MemberMeeting::ATTENDING::YES
    member_meeting.update_attributes!(attending: status)
    updated_status = get_updated_status(member_meeting)
    assert_equal updated_status, MemberMeeting::ATTENDING::NO
    
    status = MemberMeeting::ATTENDING::NO
    member_meeting.update_attributes!(attending: status)
    updated_status = get_updated_status(member_meeting)
    assert_equal updated_status, MemberMeeting::ATTENDING::YES
  end

  def test_get_rsvp_no_popup
    program = programs(:albers)
    member = members(:f_mentor)
    time = 4.weeks.ago.change(:usec => 0)
    m1 = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    member_meeting = m1.member_meetings.where(member_id: members(:f_mentor).id).first
    rsvp_text = get_rsvp_no_popup(member_meeting)
    assert_match rsvp_text, "feature.meetings.content.sure_to_attend_meeting_v3_owner".translate(meeting: _meeting)
    
    member_meeting = m1.member_meetings.where(member_id: members(:mkr_student).id).first
    member = members(:mkr_student)
    rsvp_text = get_rsvp_no_popup(member_meeting)
    assert_match rsvp_text, "feature.meetings.content.sure_to_attend_meeting_v3_html".translate(meeting: _meeting, owner_name: link_to(member_meeting.meeting.owner.try(:name), member_path(member_meeting.meeting.owner)))

    member_meeting.meeting.owner = nil
    member_meeting = m1.member_meetings.where(member_id: members(:mkr_student).id).first
    member = members(:mkr_student)
    rsvp_text = get_rsvp_no_popup(member_meeting)
    assert_match rsvp_text, "feature.meetings.content.sure_to_attend_meeting_v3_owner".translate(meeting: _meeting)
  end

  def test_embed_yes_no_button
    program = programs(:albers)
    member = members(:f_mentor)
    time = 4.weeks.ago.change(:usec => 0)
    meeting = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    content_text = "display_string.Yes".translate
    status = MemberMeeting::ATTENDING::YES
    current_occurrence_time = meeting.occurrences.first.start_time
    
    member_meeting = meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    member_meeting.update_attributes!(attending: status)
    yes_no_button_text = embed_yes_no_button(member_meeting, content_text, status, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time, outside_group: "true")
    splited_yes_no_text = yes_no_button_text.split("data-editTimeUrl")
    assert_match "outside_group=true", splited_yes_no_text[0]
    assert_match "outside_group=true", splited_yes_no_text[1]
    assert_match /Yes/, yes_no_button_text
    assert_match /cjs_rsvp_confirm/, yes_no_button_text
    assert_no_match /cjs_rsvp_accepted/, yes_no_button_text
    assert_no_match /cjs_group_meeting/, yes_no_button_text
    assert_match /btn btn-outline btn-sm/, yes_no_button_text

    yes_no_button_text = embed_yes_no_button(member_meeting, content_text, status, MemberMeeting::RSVP_SOURCE::GROUP_SIDE_PANE, :current_occurrence_time => current_occurrence_time, outside_group: "false")
    splited_yes_no_text = yes_no_button_text.split("data-editTimeUrl")
    assert_match "outside_group=false", splited_yes_no_text[0]
    assert_match "outside_group=false", splited_yes_no_text[1]

    content_text = "display_string.No".translate
    status = MemberMeeting::ATTENDING::NO
    member_meeting.update_attributes!(attending: status)
    yes_no_button_text = embed_yes_no_button(member_meeting, content_text, status, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time)
    assert_match /No/, yes_no_button_text
    assert_match /cjs_rsvp_confirm/, yes_no_button_text
    assert_match /cjs_rsvp_accepted/, yes_no_button_text
    assert_match /btn btn-outline btn-sm/, yes_no_button_text
    assert_match "data-editTimeUrl=\"/meetings/#{meeting.id}/edit?current_occurrence_time=", yes_no_button_text
    assert_match "data-meetingSelector=\"#{get_meeting_html_id({meeting: meeting, current_occurrence_time: current_occurrence_time})}\"", yes_no_button_text

    meeting = meetings(:f_mentor_mkr_student)
    @group = meeting.group
    current_occurrence_time = meeting.occurrences.first.start_time
    member_meeting = meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    status = MemberMeeting::ATTENDING::NO
    member_meeting.update_attributes!(attending: status)
    yes_no_button_text = embed_yes_no_button(member_meeting, content_text, status, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time)

    assert_match /cjs_group_meeting/, yes_no_button_text
    assert_match "data-editTimeUrl=\"/meetings/#{meeting.id}/edit?current_occurrence_time=", yes_no_button_text
    assert_match "data-meetingSelector=\"#{get_meeting_html_id({meeting: meeting, current_occurrence_time: current_occurrence_time})}\"", yes_no_button_text
  end

  def test_embed_yes_no_text
    program = programs(:albers)
    member = members(:f_mentor)
    time = 4.weeks.ago.change(:usec => 0)
    meeting = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :force_non_group_meeting => true})
    member_meeting = meeting.member_meetings.where(member_id: members(:mkr_student).id).first

    status = MemberMeeting::ATTENDING::YES
    current_occurrence_time = meeting.occurrences.first.start_time
    
    member_meeting_responded = member_meeting
    yes_no_text = embed_yes_no_text(member_meeting, member_meeting_responded, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time)
    assert_match /Attending/, yes_no_text
    assert_match /fa fa-check/, yes_no_text

    status = MemberMeeting::ATTENDING::NO
    member_meeting_responded = member_meeting
    member_meeting.update_attributes!(attending: status)
    yes_no_text = embed_yes_no_text(member_meeting, member_meeting_responded, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time, outside_group: "true")
    assert_match /Not Attending/, yes_no_text
    assert_match /fa fa-times/, yes_no_text
    assert_no_match /cjs_group_meeting/, yes_no_text
    splited_yes_no_text = yes_no_text.split("data-editTimeUrl")
    assert_match "outside_group=true", splited_yes_no_text[0]
    assert_match "outside_group=true", splited_yes_no_text[1]    

    yes_no_text = embed_yes_no_text(member_meeting, member_meeting_responded, MemberMeeting::RSVP_SOURCE::GROUP_SIDE_PANE, :current_occurrence_time => current_occurrence_time, outside_group: "false")
    splited_yes_no_text = yes_no_text.split("data-editTimeUrl")
    assert_match "outside_group=false", splited_yes_no_text[0]
    assert_match "outside_group=false", splited_yes_no_text[1]

    meeting = create_meeting({:program => program, :topic => "Arbit Topic", :start_time => time, :end_time => (time + 30.minutes), :location => "Chennai", :members => [members(:f_mentor), members(:mkr_student)], :owner_id => members(:f_mentor).id, :group => groups(:mygroup)})
    member_meeting = meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    member_meeting_response_1 = member_meeting.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::YES, :meeting_occurrence_time => member_meeting.meeting.occurrences.last.to_time )
    member_meeting_response_2 = member_meeting.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::NO, :meeting_occurrence_time => member_meeting.meeting.occurrences.last.to_time )
    
    current_occurrence_time = meeting.occurrences.first.start_time
    
    yes_no_text = embed_yes_no_text(member_meeting_response_1, member_meeting.reload, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time)
    assert_match /Attending/, yes_no_text
    assert_match /cjs_rsvp_accepted/, yes_no_text
    assert_match /cjs_rsvp_confirm/, yes_no_text
    assert_match /fa fa-check/, yes_no_text
    assert_match /cjs_group_meeting/, yes_no_text
    assert_match "data-editTimeUrl=\"/meetings/#{meeting.id}/edit?current_occurrence_time=", yes_no_text
    assert_match "data-meetingSelector=\"#{get_meeting_html_id({meeting: meeting, current_occurrence_time: current_occurrence_time})}\"", yes_no_text


    yes_no_text = embed_yes_no_text(member_meeting_response_2, member_meeting, MemberMeeting::RSVP_SOURCE::MEETING_AREA, :current_occurrence_time => current_occurrence_time)
    assert_match /Not Attending/, yes_no_text
    assert_match /cjs_rsvp_confirm/, yes_no_text
    assert_no_match /cjs_rsvp_accepted/, yes_no_text
    assert_match /fa fa-times/, yes_no_text
  end

  def test_get_meetings_mini_popup_header
    user = users(:f_mentor)

    user.stubs(:is_opted_for_slot_availability?).returns(true)

    assert_equal "<div class=\"tabs-container inner_tabs\"><div><ul class=\"nav nav-tabs h5 no-margins\"><li class=\" active\"><a data-toggle=\"tab\" href=\"#cjs_select_meeting_details_tab_content\"><span class=\"hidden-xs hidden-sm cjs_visit_details_tab\">1. Enter Topic &amp; Description</span><span class=\"hidden-lg hidden-md cjs_visit_details_tab\">1. Enter Details</span></a></li><li class=\"cjs_meeting_times_tab \"><a href=\"#select_meeting_time_tab_content\"><span class=\"hidden-xs hidden-sm cjs_calendar_meeting\">2. Select Meeting Times</span><span class=\"hidden-lg hidden-md cjs_calendar_meeting\">2. Select Times</span></a></li></ul></div></div>", get_meetings_mini_popup_header(user)

    user.stubs(:is_opted_for_slot_availability?).returns(false)

    assert_equal "<div class=\"tabs-container inner_tabs\"><div><ul class=\"nav nav-tabs h5 no-margins\"><li class=\" active\"><a data-toggle=\"tab\" href=\"#cjs_select_meeting_details_tab_content\"><span class=\"hidden-xs hidden-sm cjs_visit_details_tab\">1. Enter Topic &amp; Description</span><span class=\"hidden-lg hidden-md cjs_visit_details_tab\">1. Enter Details</span></a></li><li class=\"cjs_meeting_times_tab \"><a href=\"#select_meeting_time_tab_content\"><span class=\"hidden-xs hidden-sm cjs_ga_meeting\">2. Propose Meeting Times</span><span class=\"hidden-lg hidden-md cjs_ga_meeting\">2. Propose Times</span></a></li></ul></div></div>", get_meetings_mini_popup_header(user)
  end

  def test_get_meeting_dropdown_edit_delete
    program = programs(:albers)
    member = members(:f_mentor)
    self.expects(:wob_member).at_least(0).returns(members(:f_mentor))
    self.expects(:_meeting).at_least(0).returns("meeting")
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)

    upcoming_occurence_time = Meeting.upcoming_recurrent_meetings([meeting]).first[:current_occurrence_time]
    content = get_meeting_dropdown_edit_delete(meeting, meeting.id, upcoming_occurence_time, true, groups(:mygroup))
    set_response_text(content)
    assert_select "div.btn-group" do
      assert_select "a.edit", :text => "Edit"
      assert_select "a.delete", :text => "Delete"
    end

    #past meeting
    past_occurence_time = Meeting.past_recurrent_meetings([meeting]).first[:current_occurrence_time]
    content = get_meeting_dropdown_edit_delete(meeting, meeting.id, past_occurence_time, true, groups(:mygroup))
    set_response_text(content)
    assert_select "div.btn-group" do
      assert_select "a.edit", :text => "Edit"
      assert_select "a.delete", :text => "Delete"
    end

    meeting.stubs(:can_be_edited_by_member?).with(members(:f_mentor)).returns(false)
    meeting.stubs(:can_be_deleted_by_member?).with(members(:f_mentor)).returns(false)

    upcoming_occurence_time = Meeting.upcoming_recurrent_meetings([meeting]).first[:current_occurrence_time]
    content = get_meeting_dropdown_edit_delete(meeting, meeting.id, upcoming_occurence_time, true, groups(:mygroup))
    set_response_text(content)
    assert content.empty?
  end

  def test_get_meeting_actions
    program = programs(:albers)
    member = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    result = get_meeting_actions("meeting_id", meeting, member, Time.now)

    assert_select_helper_function_block "a.edit.edit_meeting_popup.btn-block-xxs.pull-right", result, text: "Edit Details" do
      assert_select "i.fa-pencil"
    end

    assert_select_helper_function_block "a.delete.btn-danger.btn-block-xxs.pull-right", result, text: "Delete Meeting" do
      assert_select "i.fa-trash"
    end
  end

  def test_get_meeting_delete_confirmation
    expected_output = "Are you sure you want to delete this meeting? This action cannot be undone."
    assert_equal expected_output, get_meeting_delete_confirmation
  end

  def test_get_mentee_availability_text_proposed_slot_popup
    member = members(:mkr_student)
    assert_equal "Update the meeting time and notify mkr_student madankumarrajan", get_mentee_availability_text_proposed_slot_popup(member)
    member.update_attributes(:availability_not_set_message => "Random text")
    assert_match /mkr_student madankumarrajan.*Availability.*Random text/, get_mentee_availability_text_proposed_slot_popup(member)
  end

  def test_get_recurrent_meeting_icon_tooltip_text
    member = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)

    start_time = DateTime.localize(meeting.start_time.in_time_zone(member.get_valid_time_zone), format: :short_time_small)

    end_time = DateTime.localize((meeting.start_time+meeting.schedule.duration).in_time_zone(member.get_valid_time_zone), format: :short_time_small)

    self.expects(:wob_member).at_least(0).returns(member)
    
    tooltip_text = get_recurrent_meeting_icon_tooltip_text(meeting)

    assert_match meeting.schedule.to_s, tooltip_text
    assert_match 'feature.email.tags.meeting_tags.meeting_timings.starting_from'.translate(start_time: DateTime.localize(meeting.occurrences.first.in_time_zone(wob_member.get_valid_time_zone), format: :short)), tooltip_text
    assert_match append_time_zone('feature.email.tags.meeting_tags.meeting_timings.start_to_end_time'.translate(start_time: start_time, end_time: end_time), member), tooltip_text
  end

  def test_get_meeting_end_times_for_edit
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    meeting.update_attributes(start_time: "2011-02-26 06:00:00")
    end_time = ["01:00 am", "02:00 am", "03:00 am", "04:00 am", "05:00 am", "06:00 am", "07:00 am", "07:30 am", "11:00 pm", "12:00 am"]
    possible_end_time = get_meeting_end_times_for_edit(end_time, meeting)
    assert_equal ["07:00 am", "07:30 am", "11:00 pm", "12:00 am"], possible_end_time

    # whole list if 12:00 is the meeting's start time
    meeting.update_attributes(start_time: "2011-02-26 12:00:00")
    possible_end_time = get_meeting_end_times_for_edit(end_time, meeting)
    assert_equal end_time, possible_end_time
  end

  def test_get_meeting_creation_date_text
    mr = create_meeting_request
    meeting = mr.meeting

    assert_nil mr.accepted_at
    display_time = DateTime.localize(meeting.created_at, format: :full_display_no_time_with_day_short)
    assert_match /#{display_time}/, get_meeting_creation_date_text(meeting)

    t = Time.now + 10.days
    mr.update_attributes(:accepted_at => t)
    display_time = DateTime.localize(mr.accepted_at, format: :full_display_no_time_with_day_short)
    assert_match /#{display_time}/, get_meeting_creation_date_text(meeting.reload)
  end

  def test_get_current_and_next_month_text
    member = members(:f_mentor)

    Member.any_instance.expects(:get_valid_time_zone).twice
    
    time = "April 20, 2017".to_time
    Time.stubs(:now).returns(time)
    assert_equal "(Apr & May 2017)", get_current_and_next_month_text(member)

    time = "December 20, 2017".to_time
    Time.stubs(:now).returns(time)
    assert_equal "(Dec 2017 & Jan 2018)", get_current_and_next_month_text(member)
  end

  def test_get_meeting_creation_date
    mr = create_meeting_request
    meeting = mr.meeting

    assert_nil mr.accepted_at
    assert_equal meeting.created_at, get_meeting_creation_date(meeting)

    t = Time.now + 10.days
    mr.update_attributes(:accepted_at => t)
    assert_equal mr.accepted_at.to_s, get_meeting_creation_date(meeting.reload).to_s
  end

  def test_get_meeting_text
    time = 2.days.from_now
    meeting = meetings(:f_mentor_mkr_student)
    state = get_meeting_text(meeting)
    assert_nil meeting.state
    
    meeting.update_attributes(:state => Meeting::State::CANCELLED)
    state = get_meeting_text(meeting)
    assert_equal meeting.state, Meeting::State::CANCELLED

    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_attributes(:state => Meeting::State::COMPLETED)
    state = get_meeting_text(meeting)
    assert_equal meeting.state, Meeting::State::COMPLETED
  end

  def test_state_not_displayed
    time = 2.days.from_now
    edit_time_only = true
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_equal true, state_not_displayed(meeting, edit_time_only)

    edit_time_only = false
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    assert_equal true, state_not_displayed(meeting, edit_time_only)

    time = 2.days.ago
    edit_time_only = true
    meeting = create_meeting(force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting.update_attributes!(calendar_time_available: true)
    assert_equal true, state_not_displayed(meeting, edit_time_only)

    edit_time_only = false
    assert_false state_not_displayed(meeting, edit_time_only)
  end

  def test_show_rsvp_buttons
    meeting = meetings(:f_mentor_mkr_student)
    current_occurrence_time = meeting.occurrences.first.start_time
    member_meeting = meeting.member_meetings.first
    status = MemberMeeting::ATTENDING::NO_RESPONSE
    member_meeting_response = member_meeting
    member_meeting.update_attributes!(attending: status)
    assert_false show_rsvp_buttons?(meeting, member_meeting_response, current_occurrence_time)

    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    current_occurrence_time = meeting.occurrences.first.start_time
    member_meeting = meeting.member_meetings.first
    status = MemberMeeting::ATTENDING::NO_RESPONSE
    member_meeting_response = member_meeting
    member_meeting.update_attributes!(attending: status)
    assert_equal true, show_rsvp_buttons?(meeting, member_meeting_response, current_occurrence_time)

    member_meeting = meeting.member_meetings.first
    status = MemberMeeting::ATTENDING::NO
    member_meeting_response = member_meeting
    member_meeting.update_attributes!(attending: status)
    assert_false show_rsvp_buttons?(meeting, member_meeting_response, current_occurrence_time)

    member_meeting = meeting.member_meetings.first
    status = MemberMeeting::ATTENDING::YES
    member_meeting_response = member_meeting
    member_meeting.update_attributes!(attending: status)
    assert_false show_rsvp_buttons?(meeting, member_meeting_response, current_occurrence_time)
  end

  def test_get_update_from_guest_flash
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    m1 = meeting.member_meetings.first
    m2 = meeting.member_meetings.second
    member_meeting_response_1 = m1.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::YES, :meeting_occurrence_time => meeting.occurrences.last.to_time )
    member_meeting_response_2 = m1.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::NO, :meeting_occurrence_time => meeting.occurrences.last.to_time )
    member_meeting_response_3 = m2.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::YES, :meeting_occurrence_time => meeting.occurrences.last.to_time )
    member_meeting_response_4 = m2.member_meeting_responses.create(:attending => MemberMeeting::ATTENDING::NO, :meeting_occurrence_time => meeting.occurrences.last.to_time )
    owner_name = "<span class=\"cjs-user-link-container hidden-xs hidden-sm\" id=\"4_0316f4\"><span class=\"cjs-onhover-text inline\" data-hovercard-url=\"/p/p1/users/4/hovercard.js\"><a title_method=\"name\" class=\"nickname\" href=\"/p/p1/members/3\">Good unique name</a></span></span><span class=\"hidden-lg hidden-md\"><span class=\"cjs-onhover-text inline\" data-hovercard-url=\"/p/p1/users/4/hovercard.js\"><a title_method=\"name\" class=\"nickname\" href=\"/p/p1/members/3\">Dean Parker</a></span></span>"
    flash = get_update_from_guest_flash(m1, member_meeting_response_1, owner_name)
    assert_equal flash, "Your RSVP has been updated to \"Yes\"."

    m1.update_attributes!(:attending => MemberMeeting::ATTENDING::NO)
    flash = get_update_from_guest_flash(m1, member_meeting_response_2, owner_name)
    assert_equal flash, "Your RSVP has been updated to \"No\"."

    flash = get_update_from_guest_flash(m2, member_meeting_response_4, owner_name)
    assert_equal flash, "Your RSVP has been updated to \"No\". &lt;span class=&quot;cjs-user-link-container hidden-xs hidden-sm&quot; id=&quot;4_0316f4&quot;&gt;&lt;span class=&quot;cjs-onhover-text inline&quot; data-hovercard-url=&quot;/p/p1/users/4/hovercard.js&quot;&gt;&lt;a title_method=&quot;name&quot; class=&quot;nickname&quot; href=&quot;/p/p1/members/3&quot;&gt;Good unique name&lt;/a&gt;&lt;/span&gt;&lt;/span&gt;&lt;span class=&quot;hidden-lg hidden-md&quot;&gt;&lt;span class=&quot;cjs-onhover-text inline&quot; data-hovercard-url=&quot;/p/p1/users/4/hovercard.js&quot;&gt;&lt;a title_method=&quot;name&quot; class=&quot;nickname&quot; href=&quot;/p/p1/members/3&quot;&gt;Dean Parker&lt;/a&gt;&lt;/span&gt;&lt;/span&gt; will be notified about the update."

    flash = get_update_from_guest_flash(m2, member_meeting_response_4, nil)
    assert_equal flash, "Your RSVP has been updated to \"No\"."

    m2.update_attributes!(:attending => MemberMeeting::ATTENDING::YES)
    flash = get_update_from_guest_flash(m2, member_meeting_response_3, owner_name)
    assert_equal flash, "Your RSVP has been updated to \"Yes\". &lt;span class=&quot;cjs-user-link-container hidden-xs hidden-sm&quot; id=&quot;4_0316f4&quot;&gt;&lt;span class=&quot;cjs-onhover-text inline&quot; data-hovercard-url=&quot;/p/p1/users/4/hovercard.js&quot;&gt;&lt;a title_method=&quot;name&quot; class=&quot;nickname&quot; href=&quot;/p/p1/members/3&quot;&gt;Good unique name&lt;/a&gt;&lt;/span&gt;&lt;/span&gt;&lt;span class=&quot;hidden-lg hidden-md&quot;&gt;&lt;span class=&quot;cjs-onhover-text inline&quot; data-hovercard-url=&quot;/p/p1/users/4/hovercard.js&quot;&gt;&lt;a title_method=&quot;name&quot; class=&quot;nickname&quot; href=&quot;/p/p1/members/3&quot;&gt;Dean Parker&lt;/a&gt;&lt;/span&gt;&lt;/span&gt; will be notified about the update."

    flash = get_update_from_guest_flash(m2, member_meeting_response_3, nil)
    assert_equal flash, "Your RSVP has been updated to \"Yes\"."
  end

  def test_get_ga_class
    source = Survey::SurveySource::MAIL
    assert_equal "cjs_source_mail", get_ga_class(source)

    source = Survey::SurveySource::MEETING_LISTING
    assert_equal "", get_ga_class(source)

    source = Survey::SurveySource::HOME_PAGE_WIDGET
    assert_equal "cjs_source_home_page", get_ga_class(source)

    source = ""
    assert_equal "cjs_meeting_area", get_ga_class(source)
  end

  def test_get_meeting_state
    meeting = create_meeting(force_non_group_meeting: true)
    meeting.update_attributes!(state: "0")
    assert_equal get_meeting_state(meeting), "feature.meetings.header.completed".translate

    meeting = create_meeting(force_non_group_meeting: true)
    meeting.update_attributes!(state: "1")
    assert_equal get_meeting_state(meeting), "feature.meetings.header.canceled".translate
    
    time = 2.days.from_now
    meeting = meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_equal get_meeting_state(meeting), "feature.meetings.header.upcoming".translate

    meeting = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    assert_equal get_meeting_state(meeting), "feature.meetings.header.overdue".translate
  end

  def test_get_meeting_state_class
   meeting = create_meeting(force_non_group_meeting: true)
    meeting.update_attributes!(state: "0")
    assert_equal get_meeting_state_class(meeting), "label label-primary"

    meeting = create_meeting(force_non_group_meeting: true)
    meeting.update_attributes!(state: "1")
    assert_equal get_meeting_state_class(meeting), "label label-warning"
    
    time = 2.days.from_now
    meeting = meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    assert_equal get_meeting_state_class(meeting), "label label-success"

    meeting = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    assert_equal get_meeting_state_class(meeting), "label label-danger"
  end

  def test_get_filter_count_label
    html_content = to_html get_filter_count_label("some text")
    assert_select html_content, "span.label.label-success.hide.cjs-report-filter-count", text: "some text"
  end

  def test_get_caret_class_for_admin_dashboard
    percentage = 90
    assert_equal "text-navy", get_caret_class_for_admin_dashboard(percentage)
    percentage = 0
    assert_equal "text-default", get_caret_class_for_admin_dashboard(percentage)
    percentage = -100
    assert_equal "text-default", get_caret_class_for_admin_dashboard(percentage)
  end

  def test_get_caret_class
    percentage = 80
    assert_equal get_caret_class(percentage), "text-navy"

    percentage = -80
    assert_equal get_caret_class(percentage), "text-danger"

    percentage = 0
    assert_equal get_caret_class(percentage), "text-warning"
  end

  def test_get_caret
    percentage = 80
    assert_match get_caret(percentage), get_icon_content("fa fa-caret-up")
    percentage = -80
    assert_match get_caret(percentage), get_icon_content("fa fa-caret-down")

    percentage = 0
    assert_match get_caret(percentage), get_icon_content("fa fa-unsorted")
  end

  def test_get_meeting_area_src
    src = Survey::SurveySource::MENTORING_CALENDAR
    assert_equal get_meeting_area_src(src), EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MENTORING_CALENDAR
    
    src = Survey::SurveySource::MEETING_LISTING
    assert_equal get_meeting_area_src(src), EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_LISTING
  end

  def test_get_tabs_for_mentoring_sessions_listing
    label_tab_mapping = {
        "Scheduled" => Meeting::ReportTabs::SCHEDULED,
        "Upcoming" => Meeting::ReportTabs::UPCOMING,
        "Past" => Meeting::ReportTabs::PAST
    }
    active_tab = Meeting::ReportTabs::SCHEDULED
    expects(:get_tabs_for_listing).with(label_tab_mapping, active_tab, url: mentoring_sessions_path, param_name: :tab)
    get_tabs_for_mentoring_sessions_listing(active_tab)
  end

  def test_get_unread_messages_text
    meeting = meetings(:upcoming_calendar_meeting)
    assert_match /4 unread/, get_unread_messages_text(meeting, {unread: {meeting.id => 4}})
    assert_equal "", get_unread_messages_text(meeting, {unread: {meeting.id => 0}})
  end

  def test_can_show_meeting_messages
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert_false can_show_meeting_messages?(meeting, {})
    meeting = meetings(:upcoming_calendar_meeting)
    assert_false can_show_meeting_messages?(meeting, {})
    assert_false can_show_meeting_messages?(meeting, {all: {meeting.id => 0}})
    assert can_show_meeting_messages?(meeting, {all: {meeting.id => 1}})
  end

  def test_get_error_flash_for_calendar_sync_v2
    error_list = ["Error One", "Error Two"]
    selected_date = Date.current.strftime('time.formats.full_display_no_time'.translate)

    response = get_error_flash_for_calendar_sync_v2(error_list, selected_date)
    assert_equal "Following errors occurred<br><ul><li>Error One<\\/li><li>Error Two<\\/li><\\/ul>", response

    response = get_error_flash_for_calendar_sync_v2([], selected_date)
    assert_equal "There are no available timeslots on #{selected_date}. Please choose another date.", response    
  end

  def test_can_show_meeting_notes
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert_false can_show_meeting_notes?(meeting, {})
    assert_false can_show_meeting_notes?(meeting, {meeting.id => 0})
    assert can_show_meeting_notes?(meeting, {meeting.id => 1})
    meeting = meetings(:upcoming_calendar_meeting)
    assert_false can_show_meeting_notes?(meeting, {})
    assert_false can_show_meeting_notes?(meeting, {meeting.id => 0})
    assert can_show_meeting_notes?(meeting, {meeting.id => 1})
  end

  private

  def _Meeting
    "Meeting"
  end

  def _meeting
    "meeting"
  end

end