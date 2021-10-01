require_relative './../test_helper.rb'

class MeetingsControllerTest < ActionController::TestCase
  include MentoringSlotsHelper
  include ConnectionFilters::CommonInclusions

  def setup
    super
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC, false)
    programs(:org_anna_univ).enable_feature(FeatureName::CALENDAR, true)
    programs(:org_anna_univ).enable_feature(FeatureName::CALENDAR_SYNC, false)
    chronus_s3_utils_stub
  end

  def test_create_success
    program = programs(:albers)
    template = program.mailer_templates.where(:uid => MeetingCreationNotificationToOwner.mailer_attributes[:uid]).first
    if template.present?
      template.update_attribute(:enabled, true)
      assert template.enabled?
    end
    current_user_is :f_mentor
    self.stubs(:wob_member).returns(members(:mkr_student))
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_TITLE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      assert_difference  'members(:f_mentor).meetings.size', 1 do
        assert_difference  'members(:mkr_student).meetings.size', 1 do
           assert_difference 'RecentActivity.count' do
            assert_difference 'Connection::Activity.count' do
              post :create, xhr: true, params: { :common_form => true, :from_connection_home_page_widget => true, :ei_src => ei_src, :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2025"}}
              assert_response :success
          end
        end
        end
      end
    end
    m = Meeting.last
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_CREATED
    assert_equal m.owner, RecentActivity.last.member
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, "Gen Topic"
    assert_equal m.description, "Gen Description"
    assert_equal "08:30 am February 25, 2025", m.start_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal "09:30 am February 25, 2025", m.end_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal m.owner, members(:f_mentor)
    assert_false assigns(:from_mentoring_calendar)
    assert assigns(:from_connection_home_page_widget)
    assert_equal members(:mkr_student).get_valid_time_zone, m.time_zone

    meeting = Meeting.last
    email = ActionMailer::Base.deliveries.last
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Invitation: Gen Topic", email.subject
    email_content = get_html_part_from(email)
    assert_match "You have been invited to the", email_content
    assert_match "Yes, I will attend", email_content
    assert_match "No, I will not attend", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting.end_time.strftime('%I:%M %P'), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    meeting.member_meetings.each do |mm|
      assert_nil mm.reminder_time
    end
  end

  def test_create_assigns_redirect_to_path
    current_user_is :f_mentor
    group = groups(:mygroup)
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_TITLE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).once
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        post :create, xhr: true, params: { :common_form => true, :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
      :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2025"}, view_mode: 2, ei_src: ei_src, :from_mentoring_calendar => true}
      end
    end
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_CREATED
    assert_response :success
    assert assigns(:from_mentoring_calendar)
    assert_false assigns(:from_connection_home_page_widget)
    assert_nil assigns(:favorite_user_ids)
  end

  def test_create_assigns_redirect_to_path_from_goal
    current_user_is :f_mentor
    group = groups(:mygroup)
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_TASK
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).once
    post :create, xhr: true, params: { :common_form => true, :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
      :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2025"}, :from_goal => true, ei_src: ei_src}
    assert_response :success
    meeting = Meeting.last
    assert_nil meeting.mentee_id
  end

  def test_create_success_with_mst_time_zone
    program = programs(:albers)
    template = program.mailer_templates.where(:uid => MeetingCreationNotificationToOwner.mailer_attributes[:uid]).first
    if template.present?
      template.update_attribute(:enabled, true)
      assert template.enabled?
    end
    members(:f_mentor).update_attribute(:time_zone, "America/Denver")
    current_user_is :f_mentor
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_SIDE_PANE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      assert_difference  'members(:f_mentor).meetings.size', 1 do
        assert_difference  'members(:mkr_student).meetings.size', 1 do
          post :create, xhr: true, params: { :common_form => true, ei_src: ei_src, :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "August 25, 2025"}}
          assert_response :success
        end
      end
    end
    m = Meeting.last
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, "Gen Topic"
    assert_equal m.description, "Gen Description"
    assert_equal "08:30 am August 25, 2025", m.start_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal "09:30 am August 25, 2025", m.end_time.strftime('%I:%M %P %B %d, %Y')
    assert_equal m.owner, members(:f_mentor)
  end

  def test_create_success_timezone
    program = programs(:albers)
    members(:f_mentor).update_attribute(:time_zone, "America/Denver")
    current_user_is :f_mentor
    start_date = 2.months.from_now
    start_date = start_date-start_date.wday.days
    end_date = start_date + 6.days
    assert_difference  'members(:f_mentor).meetings.size', 1 do
      post :create, xhr: true, params: { :meeting => {:group_id => groups(:mygroup).id, :recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::DAILY,
          :repeats_by_month_date => true, :topic => "Gen Topic", :start_time_of_day => '12:00 am', :end_time_of_day => '12:30 am',
          :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => start_date.strftime('%b %d, %Y'), :repeats_end_date => end_date.strftime('%b %d, %Y')}}
      assert_response :success
    end
    m = Meeting.last
    assert_equal 7, m.occurrences.size
    assert_equal end_date.utc.to_date, m.occurrences.last.utc.to_date
  end

  def test_create_failure
    current_user_is :f_mentor
    start_date = 2.months.from_now
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_SIDE_PANE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).never
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      assert_difference  'members(:f_mentor).meetings.size', 0 do
        assert_difference  'members(:mkr_student).meetings.size', 0 do
          post :create, xhr: true, params: { :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '06:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => start_date.strftime('%b %d, %Y'), ei_src: ei_src}}
        end
      end
    end
  end

  def test_create_without_occurrences
    current_user_is :f_mentor
    start_date = 2.months.from_now
    start_date = start_date-start_date.wday.days
    end_date = start_date + 2.days
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_MEETING_LIST
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).never
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      assert_difference  'members(:f_mentor).meetings.size', 0 do
        assert_difference  'members(:mkr_student).meetings.size', 0 do
          post :create, xhr: true, params: { :meeting => {:group_id => groups(:mygroup).id, :recurrent => true, :repeat_every => 1, :schedule_rule => Meeting::Repeats::WEEKLY,
            :repeats_by_month_date => true, :topic => "Gen Topic", :start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am', :repeats_on_week => ["5"],
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => start_date.strftime('%b %d, %Y'), :repeats_end_date => end_date.strftime('%b %d, %Y'), ei_src: ei_src}
          }
        end
      end
    end
    assert_equal "The meeting could not be created as there can be no occurrences of the meeting between provided start date and end date", assigns(:error_flash)
  end

  def test_index
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)
    get :index, params: { :group_id => groups(:mygroup).id}
    assert_equal [{:current_occurrence_time => m.occurrences.first, :meeting => m}], assigns(:meetings_to_be_held)
    assert_equal [{:current_occurrence_time => meetings(:f_mentor_mkr_student).occurrences.first, :meeting => meetings(:f_mentor_mkr_student)}], assigns(:archived_meetings)
    assert_false assigns(:can_current_user_create_meeting)
    assert assigns(:skip_meetings_side_pane)
    assert_equal assigns(:ei_src), EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
  end

  def test_index_feature_disabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    current_user_is :f_mentor
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    assert_raise Authorization::PermissionDenied do
      get :index
    end
  end

  def test_index_with_mentoring_connections_V2_enabled
    current_user_is :f_mentor
    group = groups(:mygroup)
    programs(:org_primary).enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    assert_permission_denied do
      get :index, params: { :group_id => group.id}
    end

  end

  def test_index_non_group_member
    current_user_is :f_student

    assert_raise Authorization::PermissionDenied do
      get :index, params: { :group_id => groups(:mygroup).id}
    end
  end

  def test_xhr_index
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :mkr_student
    m = create_mentoring_slot(:member => members(:mkr_student))
    mentoring_slots(:f_mentor).update_attributes(:start_time => (Time.now - 5.minutes), :end_time => (Time.now + 5.minutes))
    assert m.valid?
    st = Time.now - 5.days
    en = Time.now + 5.days
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :index, xhr: true, params: { :group_id => groups(:mygroup)}
      end
    end
    assert_equal groups(:mygroup), assigns(:group)
    assert_equal assigns(:ei_src), EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
  end

  def test_index_declined_meetings
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :mkr_student
    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)
    get :index, params: { :group_id => groups(:mygroup).id}
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, members(:mkr_student).member_meetings.find_by(meeting_id: m.id).attending
    assert_equal [{:current_occurrence_time => m.start_time, :meeting => m}], assigns(:meetings_to_be_held),
    members(:mkr_student).mark_attending!(m, attending: MemberMeeting::ATTENDING::NO)
    assert_false members(:mkr_student).is_attending?(m, m.start_time)
    get :index, params: { :group_id => groups(:mygroup).id}
    assert_equal  [{:current_occurrence_time => m.start_time, :meeting => m}], assigns(:meetings_to_be_held)
  end

  def test_inactive_meeting
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :mkr_student
    get :index, params: { :group_id => groups(:mygroup).id, meeting_id: meeting.id}
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, members(:mkr_student).member_meetings.find_by(meeting_id: meeting.id).attending
    assert_equal "The meeting you are trying to access does not exist.", flash[:error]
    assert_redirected_to root_path
  end

  def test_new
    current_user_is :f_student
    current_organization_is :org_primary
    start_time = (Time.now.utc + 2.days).beginning_of_day + 8.hours
    end_time = start_time + 3.hours
    get :new, params: { :mentor_id => members(:mentor_1).id, :start_time => start_time, :end_time => end_time}
    assert_equal assigns(:mentor), members(:mentor_1)
    assert assigns(:new_meeting).new_record?
    assert_equal assigns(:new_meeting).start_time, start_time
    assert_equal assigns(:new_meeting).end_time, start_time + 30.minutes
    assert_equal assigns(:role), members(:mentor_1).roles[0].name
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_false assigns(:unlimited_slot)
    assert assigns(:valid_end_time)

    mentor_user = users(:mentor_1)
    assert assigns(:can_render_calendar_ui)
    assert_equal [mentor_user.id], assigns(:mentors_with_slots).keys
    assert_equal [mentor_user.id], assigns(:active_or_drafted_students_count).keys
    assert_equal [mentor_user.students(:active_or_drafted).size], assigns(:active_or_drafted_students_count).values
    assert_false assigns(:sent_mentor_offers_pending).present?

    assert_nil assigns(:mentor_draft_count)
    assert_equal [mentor_user.id], assigns(:students_count).keys
    assert_equal [mentor_user.students(:active).size], assigns(:students_count).values
    assert_equal programs(:albers).required_profile_questions_except_default_for(RoleConstants::MENTOR_NAME), assigns(:mentor_required_questions)
  end

  def test_new_for_inadequate_time_slot
    current_user_is :f_student
    current_organization_is :org_primary
    current_program_is :albers
    current_program = programs(:albers)
    current_program.calendar_setting.update_attribute(:slot_time_in_minutes, 0)
    start_time = (Time.now.utc + 2.days).beginning_of_day + 8.hours
    end_time = start_time + 20.minutes
    get :new, params: { :mentor_id => members(:f_mentor).id, :start_time => start_time, :end_time => end_time}
    assert_equal assigns(:mentor), members(:f_mentor)
    assert assigns(:new_meeting).new_record?
    assert_equal assigns(:new_meeting).start_time, start_time
    assert_equal assigns(:new_meeting).end_time, start_time + 20.minutes
    assert_nil assigns(:role)
    assert_nil assigns(:profile_questions)
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert assigns(:unlimited_slot)
    assert assigns(:valid_end_time)

    assert_nil assigns(:can_render_calendar_ui)
    assert_nil assigns(:mentors_with_slots)
    assert_nil assigns(:active_or_drafted_students_count)
    assert_nil assigns(:sent_mentor_offers_pending)
    assert_nil assigns(:mentor_draft_count)
    assert_nil assigns(:students_count)
    assert_nil assigns(:mentor_required_questions)
  end

  def test_new_for_inadequate_advance_slot_booking_time
    program = programs(:albers)
    program.calendar_setting.update_attributes(slot_time_in_minutes: 0, advance_booking_time: 120)
    start_time = (Time.current + 1.day).beginning_of_day
    end_time = start_time + 60.minutes

    current_user_is :f_student
    get :new, params: { mentor_id: members(:f_mentor).id, start_time: start_time, end_time: end_time }
    assert assigns(:new_meeting).new_record?
    assert assigns(:unlimited_slot)
    assert_false assigns(:valid_end_time)
    assert_equal assigns(:mentor), members(:f_mentor)
    assert_equal assigns(:new_meeting).start_time, start_time
    assert_equal start_time + 60.minutes, assigns(:new_meeting).end_time
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_nil assigns(:role)
    assert_nil assigns(:profile_questions)
    assert_nil assigns(:can_render_calendar_ui)
    assert_nil assigns(:mentors_with_slots)
    assert_nil assigns(:active_or_drafted_students_count)
    assert_nil assigns(:sent_mentor_offers_pending)
    assert_nil assigns(:mentor_draft_count)
    assert_nil assigns(:students_count)
    assert_nil assigns(:mentor_required_questions)
  end

  def test_update_success_inside_three_membered_group
    start_time = (Time.current + 2.days).beginning_of_day + 30.minutes
    end_time = start_time + 30.minutes
    meeting = create_meeting(start_time: start_time - 30.minutes, end_time: end_time - 30.minutes)

    group = groups(:mygroup)
    group.update_members(group.mentors, group.students + [users(:f_student)])
    group.reload

    ei_src = EngagementIndex::Src::UpdateMeeting::MEMBER_MEETING_LISTING
    self.stubs(:wob_member).returns(members(:mkr_student))
    meeting_upcoming = Meeting.upcoming_recurrent_meetings(meeting.group.meetings)
    meeting_upcoming = wob_member.get_attending_and_not_responded_meetings(meeting_upcoming)
    @controller.expects(:get_meetings_for_sidepanes).with(meeting.group, nil).returns([meeting_upcoming, meeting_upcoming])
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, context_place: ei_src).once
    current_user_is :f_mentor
    assert_emails 2 do
      assert_difference 'RecentActivity.count' do
        assert_difference 'Connection::Activity.count' do
          put :update, xhr: true, params: { id: meeting.id, ei_src: ei_src, meeting: { topic: "Genmax Topic", description: "Gen Description",
            start_time_of_day: start_time.strftime('%I:%M %p'), end_time_of_day: end_time.strftime('%I:%M %p'), date: start_time.strftime('%b %d, %Y'),
            attendee_ids: members(:mkr_student, :f_student).map(&:id), edit_option: Meeting::EditOption::ALL }, group_id: group }
        end
      end
    end
    meeting.reload
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_UPDATED
    assert_equal RecentActivity.last.member, assigns(:meeting).updated_by_member
    assert_equal_unordered members(:f_mentor, :mkr_student, :f_student), meeting.members
    assert_equal group, meeting.group
    assert_equal "Genmax Topic", meeting.topic
    assert_equal "Gen Description", meeting.description
    assert_equal meeting_upcoming, assigns(:upcoming_meetings)
    assert_equal meeting_upcoming, assigns(:upcoming_meetings_in_next_seven_days)
    assert_time_string_equal start_time, meeting.start_time
    assert_time_string_equal end_time, meeting.end_time

    email, email1 = ActionMailer::Base.deliveries.last(2)
    email_content = get_html_part_from(email)
    assert_equal email.to.first, users(:f_student).email
    assert_equal email1.to.first, users(:mkr_student).email
    assert_equal "Updated: Genmax Topic", email.subject
    assert_match meeting.topic, email_content
    assert_match meeting.description, email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting.end_time.strftime("%B %d, %Y"), email_content
    meeting.members.each { |member| assert_match member.name, email_content }
  end

  def test_update_for_two_member_group
    current_user_is :f_mentor
    st = (Time.current - 2.days).beginning_of_day
    en = st + 30.minutes
    meeting = meetings(:f_mentor_mkr_student)
    meeting.member_meetings.update_all(attending: MemberMeeting::ATTENDING::YES)

    # meeting is archived, so no update mail
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {context_place: ei_src}).once
    assert_no_emails do
      assert_difference 'Connection::Activity.count' do
        assert_difference 'RecentActivity.count' do
          put :update, xhr: true, params: { id: meeting.id, ei_src: ei_src, meeting: {topic: "Genmax Topic", description: "Gen Description",
            start_time_of_day: st.strftime('%I:%M %p'), end_time_of_day: en.strftime('%I:%M %p'), date: st.strftime('%b %d, %Y'), edit_option: Meeting::EditOption::ALL}, group_id: meetings(:f_mentor_mkr_student).group.id }
        end
      end
    end
    m = meeting.reload
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_UPDATED
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, "Genmax Topic"
    assert_equal m.description, "Gen Description"
    assert_time_string_equal(m.start_time, st)
    assert_time_string_equal(m.end_time, en)
  end

  def test_update_fail_when_member_cant_edit_meeting
    current_user_is :f_mentor
    st = (Time.current - 2.days).beginning_of_day
    en = st + 30.minutes
    meeting = meetings(:f_mentor_mkr_student)
    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(false)
    assert_no_emails do
      assert_permission_denied do
        put :update, xhr: true, params: { id: meeting.id, meeting: {topic: "Genmax Topic", description: "Gen Description",
            start_time_of_day: st.strftime('%I:%M %p'), end_time_of_day: en.strftime('%I:%M %p'), date: st.strftime('%b %d, %Y'), edit_option: Meeting::EditOption::ALL}, group_id: meetings(:f_mentor_mkr_student).group.id }
      end
    end
  end

  def test_edit_fail_when_cant_edit_meeting
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)
    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(false)
    assert_permission_denied do
      get :edit, params: { id: meeting.id, current_occurrence_time: meeting.occurrences.first.start_time.to_s, outside_group: "false", show_recurring_options: "false", meeting_area: "false", from_connection_home_page_widget: true }
    end
    assert_response :success
  end

  def test_group_meeting_reschedule_all
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    current_user_is :f_mentor
    old_meeting_attributes = m.attributes
    old_start_time = m.start_time
    assert_nil m.time_zone
    assert_emails 1 do
      put :update, xhr: true, params: { :id => m.id , :meeting_area => false , :outside_group => "true" , :set_meeting_time => true , :edit_option => Meeting::EditOption::ALL , :meeting => {:start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p') ,
        :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :attendee_ids=>[members(:f_mentor).id, members(:mkr_student).id]}}
    end
    m.reload
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time + 30.minutes)
    assert_equal m.schedule.duration, 30.minutes
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
    assert_equal members(:f_mentor).get_valid_time_zone, m.time_zone

    #Update from meeting liusting page
    assert_emails 1 do
      old_start_time = m.start_time
      put :update, xhr: true, params: { :id => m.id , :meeting_area => true , :outside_group => "true" , :set_meeting_time => true , :edit_option => Meeting::EditOption::ALL , :meeting => {:start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p') ,
        :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :attendee_ids=>[members(:f_mentor).id, members(:mkr_student).id]}}
    end
    m.reload
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time + 30.minutes)
    assert_equal m.schedule.duration, 30.minutes
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
  end

  def test_group_meeting_reschedule_current_in_recurrent
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    old_meeting_attributes = m.attributes
    current_user_is :f_mentor
    old_start_time = m.start_time
    old_last_occurrence = m.occurrences.last
    current_occurrence_time = m.occurrences.last(2).first.start_time

    assert_emails 1 do
      put :update, xhr: true, params: { :id => m.id , :meeting_area => true ,:outside_group => "true" ,:set_meeting_time => true , :edit_option => Meeting::EditOption::CURRENT , :meeting => {:start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}}
    end
    m.reload
    last_occurrence = m.occurrences.last
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    assert_equal old_last_occurrence.start_time,last_occurrence.start_time
    assert_equal old_last_occurrence.end_time,last_occurrence.end_time
    new_meeting = Meeting.last
    assert_equal new_meeting.topic, m.topic
    assert_equal new_meeting.description, m.description
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 30.minutes)
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
    assert_nil m.time_zone
    assert_equal members(:f_mentor).get_valid_time_zone, new_meeting.time_zone

    api = mock()
    api.stubs(:update_calendar_event).returns(nil)
    Calendar::GoogleApi.stubs(:new).returns(api)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.any_instance.stubs(:create_calendar_event).returns(nil)
    Meeting.expects(:handle_update_calendar_event).twice

    #Update from meeting liusting page
    old_last_occurrence = m.occurrences.last
    assert_emails 4 do
      current_occurrence_time = m.occurrences.last(2).first.start_time
      put :update, xhr: true, params: { :id => m.id , :meeting_area => false , :outside_group => "true" , :set_meeting_time => true , :edit_option => Meeting::EditOption::CURRENT , :meeting => {:start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}}
    end
    m.reload
    last_occurrence = m.occurrences.last
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    assert_equal old_last_occurrence.start_time,last_occurrence.start_time
    assert_equal old_last_occurrence.end_time,last_occurrence.end_time
    new_meeting = Meeting.last
    assert_equal new_meeting.topic, m.topic
    assert_equal new_meeting.description, m.description
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 30.minutes)
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
  end

  def test_group_reschedule_following_in_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    old_meeting_attributes = m.attributes
    current_user_is :f_mentor
    old_start_time = m.start_time
    current_occurrence_time = m.occurrences.last(2).first.start_time
    assert_emails 1 do
      put :update, xhr: true, params: { :id => m.id , :edit_option => Meeting::EditOption::FOLLOWING , :meeting_area => true , :outside_group => "true" , :set_meeting_time => true , :meeting => {:start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}}
    end
    m.reload
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    new_meeting = Meeting.last
    assert_equal new_meeting.topic, m.topic
    assert_equal new_meeting.description, m.description
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 30.minutes)
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
    assert_nil m.time_zone
    assert_equal members(:f_mentor).get_valid_time_zone, new_meeting.time_zone
    assert assigns(:from_meeting_area)

    api = mock()
    api.stubs(:update_calendar_event).returns(nil)
    Calendar::GoogleApi.stubs(:new).returns(api)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.any_instance.stubs(:create_calendar_event).returns(nil)
    Meeting.expects(:handle_update_calendar_event).twice

    #update from listing page
    old_meeting_attributes = m.attributes
    old_start_time = m.start_time
    assert_emails 4 do
      current_occurrence_time = m.occurrences.last(2).first.start_time
      put :update, xhr: true, params: { :id => m.id , :edit_option => Meeting::EditOption::FOLLOWING , :meeting_area => false,:outside_group => "true" , :set_meeting_time => true , :meeting => {:start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}}
    end
    m.reload
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    new_meeting = Meeting.last
    assert_equal new_meeting.topic, m.topic
    assert_equal new_meeting.description, m.description
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 30.minutes)
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
    assert_false assigns(:from_meeting_area)
  end

  def test_update_all_in_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    current_user_is :f_mentor
    old_start_time = m.start_time
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once

    assert_emails 1 do
      assert_difference 'Connection::Activity.count' do
        assert_difference 'RecentActivity.count' do
          assert_difference 'MemberMeetingResponse.count', -4 do
            put :update, xhr: true, params: { :id => m.id, :ei_src => ei_src, :edit_option => Meeting::EditOption::ALL, :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
              :start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}, group_id: meetings(:f_mentor_mkr_student).group.id
            }
          end
        end
      end
    end
    m.reload
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_UPDATED
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, "Genmax Topic"
    assert_equal m.description, "Gen Description"
    assert_time_string_equal(m.start_time, old_start_time + 30.minutes)
    assert_equal m.schedule.duration, 30.minutes
    assert_equal "Updated: #{m.topic}", ActionMailer::Base.deliveries.last.subject
  end

  def test_update_current_in_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    old_meeting_attributes = m.attributes
    current_user_is :f_mentor
    old_start_time = m.start_time
    current_occurrence_time = m.occurrences.last(2).first.start_time
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once
    assert_emails 1 do
      assert_difference 'Connection::Activity.count', 1 do
        assert_difference 'RecentActivity.count', 1 do
          assert_difference 'MemberMeetingResponse.count', -1 do
            put :update, xhr: true, params: { :id => m.id, :ei_src => ei_src, :edit_option => Meeting::EditOption::CURRENT, :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
              :start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}, group_id: meetings(:f_mentor_mkr_student).group.id
            }
          end
        end
      end
    end
    m.reload
    recent_activity = RecentActivity.last
    # assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_UPDATED
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    new_meeting = Meeting.last
    assert_equal_unordered new_meeting.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal new_meeting.group, groups(:mygroup)
    assert_equal new_meeting.topic, "Genmax Topic"
    assert_equal new_meeting.description, "Gen Description"
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 30.minutes)
    assert_equal "Updated: #{new_meeting.topic}", ActionMailer::Base.deliveries.last.subject
    assert_equal Meeting.last, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::MEETING_UPDATED, recent_activity.action_type
  end

  def test_update_following_in_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    old_meeting_attributes = m.attributes
    current_user_is :f_mentor
    old_start_time = m.start_time
    current_occurrence_time = m.occurrences.last(2).first.start_time
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once
    assert_emails 1 do
      assert_difference 'Connection::Activity.count', 1 do
        assert_difference 'RecentActivity.count', 1 do
          assert_difference 'MemberMeetingResponse.count', -2 do
            put :update, xhr: true, params: { :id => m.id, :ei_src => ei_src, :edit_option => Meeting::EditOption::FOLLOWING, :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
              :start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id]}, group_id: meetings(:f_mentor_mkr_student).group.id
            }
          end
        end
      end
    end
    m.reload
    recent_activity = RecentActivity.last
    # assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_UPDATED
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    new_meeting = Meeting.last
    assert_equal_unordered new_meeting.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal new_meeting.group, groups(:mygroup)
    assert_equal new_meeting.topic, "Genmax Topic"
    assert_equal new_meeting.description, "Gen Description"
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 30.minutes)
    assert_equal "Updated: #{new_meeting.topic}", ActionMailer::Base.deliveries.last.subject
    assert_equal Meeting.last, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::MEETING_UPDATED, recent_activity.action_type
  end

  def test_update_details_not_updated
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)
    # to avoid end_time being short of start_time during update
    meeting.start_time = "03:00 PM"
    meeting.end_time = "03:30 PM"
    meeting.update_schedule
    meeting.save!

    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, context_place: ei_src).never
    assert_no_emails do
      put :update, xhr: true, params: { ei_src: ei_src, id: meeting.id , meeting: { topic: meeting.topic, description: meeting.description,
        start_time_of_day: meeting.start_time.strftime('%I:%M %p'), end_time_of_day: meeting.end_time.strftime('%I:%M %p'),
        date: meeting.start_time.strftime('%b %d, %Y'), location: meeting.location, edit_option: Meeting::EditOption::ALL }, group_id: meeting.group_id }
    end
  end

  def test_update_datetime_location_not_updated
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)
    # to avoid end_time being short of start_time during update
    meeting.start_time = "08:00 AM"
    meeting.end_time = "08:30 AM"
    meeting.update_schedule
    meeting.save!
    meeting.member_meetings.update_all(attending: MemberMeeting::ATTENDING::YES)

    Meeting.any_instance.stubs(:archived?).returns(false)
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, context_place: ei_src).once
    assert_emails do
      put :update, xhr: true, params: { id: meeting.id , ei_src: ei_src, meeting: { topic: "Updated Topic #{meeting.topic}", description: meeting.description,
        start_time_of_day: meeting.start_time.strftime('%I:%M %p'), end_time_of_day: meeting.end_time.strftime('%I:%M %p'),
        date: meeting.start_time.strftime('%b %d, %Y'), location: meeting.location, edit_option: Meeting::EditOption::ALL }, group_id: meeting.group_id }
    end
    email = ActionMailer::Base.deliveries.last
    assert_match /Confirmed the previous/, get_text_part_from(email).gsub("\n", " ")
    assert_no_match(/update your response/, get_text_part_from(email).gsub("\n", " "))
  end

  def test_update_outside_group
    current_user_is :f_mentor
    st = (Time.current + 1.day).beginning_of_day
    en = st + 1.hour
    meetings(:f_mentor_mkr_student).update_attribute(:group_id, nil)
    meetings(:f_mentor_mkr_student).update_attribute(:mentee_id, members(:mkr_student).id)
    meetings(:f_mentor_mkr_student).reload
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once
    assert_emails 1 do
      put :update, xhr: true, params: { :ei_src => ei_src, :id => meetings(:f_mentor_mkr_student).id , :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
        :start_time_of_day => st.strftime('%I:%M %p'), :end_time_of_day => en.strftime('%I:%M %p'), :date => st.strftime('%b %d, %Y')}, outside_group: "true"
      }
    end
    m = meetings(:f_mentor_mkr_student).reload
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_nil m.group
    assert_equal m.topic, "Genmax Topic"
    assert_equal m.description, "Gen Description"
    assert_time_string_equal(m.start_time, st)
    assert_time_string_equal(m.end_time, en)

    email = ActionMailer::Base.deliveries.last
    assert_equal "Updated: Genmax Topic", email.subject
    email_text = get_text_part_from(email).gsub("\n", " ")
    assert_match /Attending\?/, email_text
  end

  def test_destroy_success
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)
    time_now = Time.now.utc.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    update_recurring_meeting_start_end_date(meeting, (time_now + 4.hours), (time_now + 5.hours), options = {duration: 1.hour})
    assert meeting.active?
    assert_difference 'Meeting.count', -1 do
      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        assert_difference 'Connection::Activity.count' do
          assert_difference 'RecentActivity.count' do
            delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student).id, :group_id => meetings(:f_mentor_mkr_student).group.id}
          end
        end
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY

    email_content = get_html_part_from(email)

    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Cancelled: Arbit Topic", email.subject
    assert_match "has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_false meeting.reload.active?
    assert_false assigns(:from_connection_home_page_widget)
  end

  def test_destroy_from_meeting_area
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)

    assert meeting.active?

    assert_difference 'Meeting.count', -1 do
      assert_difference 'Connection::Activity.count' do
        assert_difference 'RecentActivity.count' do
          delete :destroy, xhr: true, params: { id: meetings(:f_mentor_mkr_student).id, group_id: meetings(:f_mentor_mkr_student).group.id, meeting_area: "true"}
        end
      end
    end

    assert_false meeting.reload.active?
    assert assigns(:from_meeting_area)
    assert_match "The meeting has been successfully removed", flash[:notice]
  end

  def test_should_not_send_email_on_archived_meeting_destroy
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)
    time_now = Time.now.utc
    assert meeting.active?

    meeting.update_attributes(:start_time => (time_now - 4.hours), :end_time => (time_now - 3.hours))

    assert_difference 'Meeting.count', -1 do
      assert_no_difference 'ActionMailer::Base.deliveries.size' do
        assert_difference 'Connection::Activity.count' do
          assert_difference 'RecentActivity.count' do
            delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student).id, :group_id => meetings(:f_mentor_mkr_student).group.id, :from_connection_home_page_widget => true}
          end
        end
      end
    end
    assert_false meeting.reload.active?
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert assigns(:from_connection_home_page_widget)
  end

  def test_update_from_guest
    current_user_is :mkr_student
    meeting = meetings(:f_mentor_mkr_student)
    program = meeting.program
    start_time = (Time.now + 2.days).change(usec: 0)
    update_recurring_meeting_start_end_date(meeting, start_time, start_time+30.minutes)
    members(:mkr_student).mark_attending!(meeting)
    assert members(:mkr_student).reload.is_attending?(meeting, meeting.start_time)

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    #For Mocking get_meetings_for_sidepanes
    self.stubs(:wob_member).returns(members(:mkr_student))
    meeting_upcoming = Meeting.upcoming_recurrent_meetings(meeting.group.meetings)
    meeting_upcoming = wob_member.get_attending_and_not_responded_meetings(meeting_upcoming)
    @controller.expects(:get_meetings_for_sidepanes).with(meetings(:f_mentor_mkr_student).group, nil).returns([meeting_upcoming, meeting_upcoming])
    #For mocking the allow exec check_member_or_admin
    @controller.expects(:check_member_or_admin_for_meeting).returns(true)
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).never
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      put :update_from_guest, xhr: true, params: { :id => meeting.id, :attending => MemberMeeting::ATTENDING::NO, :current_occurrence_time => meetings(:f_mentor_mkr_student).start_time, :src => MemberMeeting::RSVP_SOURCE::GROUP_SIDE_PANE, outside_group: "false", :group_id => meetings(:f_mentor_mkr_student).group.id, from_connection_home_page_widget: true}
    end
    meetings(:f_mentor_mkr_student).reload
    assert_false members(:mkr_student).is_attending?(meeting, meeting.start_time)
    assert_false assigns(:outside_group)
    assert_equal assigns(:upcoming_meetings), meeting_upcoming
    assert_equal assigns(:upcoming_meetings_in_next_seven_days), meeting_upcoming
    assert assigns(:current_user).present?
    assert assigns(:from_connection_home_page_widget)
    assert_false assigns(:group).nil?
    assert_false assigns(:is_admin_view)
    assert MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source

    email = ActionMailer::Base.deliveries.last
    assert_equal email.to.first, meeting.owner.email
    assert_equal "Declined: Arbit Topic", email.subject
    assert_match "has declined the meeting", get_html_part_from(email)
    assert_match meeting.topic, get_html_part_from(email)
    assert_match meeting.description, get_html_part_from(email)
    assert_match meeting.start_time.strftime("%B %d, %Y"), get_html_part_from(email)
    assert_match meeting.start_time.strftime("%B %d, %Y"), get_html_part_from(email)
    assert_nil assigns(:meeting_area)
    assert_equal assigns(:member_meeting), meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    assert_equal assigns(:member_meeting_response), meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    assert_equal MemberMeeting::RSVP_SOURCE::GROUP_SIDE_PANE, assigns(:rsvp_src)
  end

  def test_update_from_guest_for_an_occurrence
    current_user_is :mkr_student
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    daily_meeting_1 = meeting.occurrences[2]
    daily_meeting_2 = meeting.occurrences[7]
    assert_false members(:mkr_student).is_attending?(meeting, daily_meeting_1.start_time)
    program = meeting.program
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      put :update_from_guest, xhr: true, params: { :id => meeting.id, :attending => MemberMeeting::ATTENDING::YES, :current_occurrence_time => daily_meeting_1.start_time}
    end
    meetings(:f_mentor_mkr_student_daily_meeting).reload
    assert members(:mkr_student).is_attending?(meeting, daily_meeting_1.start_time)
    assert_false assigns(:from_connection_home_page_widget)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once
    assert_false members(:mkr_student).is_attending?(meeting, daily_meeting_2.start_time)
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      put :update_from_guest, xhr: true, params: { :id => meeting.id, :attending => MemberMeeting::ATTENDING::YES, :current_occurrence_time => daily_meeting_2.start_time}
    end
    meetings(:f_mentor_mkr_student_daily_meeting).reload
    assert members(:mkr_student).is_attending?(meeting, daily_meeting_2.start_time)

    student_member_meeting_response = meeting.member_meeting_responses.find_by(meeting_occurrence_time: daily_meeting_2
      .start_time)
    assert MemberMeeting::RSVP_CHANGE_SOURCE::APP, student_member_meeting_response.rsvp_change_source
    email = ActionMailer::Base.deliveries.last
    assert_equal email.to.first, meeting.owner.email
    assert_equal "Accepted: Arbit Daily Topic", email.subject
    assert_match "has accepted the meeting", get_html_part_from(email)
    assert_match meeting.topic, get_html_part_from(email)
    assert_match meeting.description, get_html_part_from(email)
    assert_match daily_meeting_2.start_time.strftime("%B %d, %Y"), get_html_part_from(email)
    assert_match daily_meeting_2.end_time.strftime("%B %d, %Y"), get_html_part_from(email)
    assert_equal assigns(:member_meeting), meeting.member_meetings.where(member_id: members(:mkr_student).id).first
    assert_equal assigns(:member_meeting_response), meeting.member_meetings.where(member_id: members(:mkr_student).id).first.member_meeting_responses.where(meeting_occurrence_time: daily_meeting_2.start_time).first
    assert_nil assigns(:rsvp_src)
    assert MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
  end

  def test_update_from_guest_mark_attending
    current_user_is :mkr_student
    members(:mkr_student).mark_attending!(meetings(:f_mentor_mkr_student), attending: MemberMeeting::ATTENDING::NO)
    assert_false members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    program = users(:mkr_student).program
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once
    get :update_from_guest, xhr: true, params: { :id => meetings(:f_mentor_mkr_student).id, :attending => MemberMeeting::ATTENDING::YES}
    meetings(:f_mentor_mkr_student).reload
    assert members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP, meetings(:f_mentor_mkr_student).member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
  end

  def test_update_from_guest_mark_attending_with_owner_user_removed_from_program
    current_user_is :mkr_student
    members(:mkr_student).mark_attending!(meetings(:f_mentor_mkr_student), attending: MemberMeeting::ATTENDING::NO)
    assert_false members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)

    assert_equal members(:f_mentor), meetings(:f_mentor_mkr_student).owner
    Member.any_instance.stubs(:user_in_program).returns(nil)

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    program = users(:mkr_student).program

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once
    get :update_from_guest, xhr: true, params: { :id => meetings(:f_mentor_mkr_student).id, :attending => MemberMeeting::ATTENDING::YES}
    meetings(:f_mentor_mkr_student).reload
    assert members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    assert_match "Your RSVP has been updated to \"Yes\"", flash[:notice]
    assert_nil assigns(:owner_name)
  end

  def test_update_from_guest_mark_attending_with_owner_removed_from_meeting
    current_user_is :mkr_student
    members(:mkr_student).mark_attending!(meetings(:f_mentor_mkr_student), attending: MemberMeeting::ATTENDING::NO)
    assert_false members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)

    assert_equal members(:f_mentor), meetings(:f_mentor_mkr_student).owner
    meetings(:f_mentor_mkr_student).member_meetings.find_by(member_id: members(:f_mentor).id).destroy

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    program = users(:mkr_student).program
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once

    get :update_from_guest, xhr: true, params: { :id => meetings(:f_mentor_mkr_student).id, :attending => MemberMeeting::ATTENDING::YES}
    meetings(:f_mentor_mkr_student).reload
    assert members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    assert_match "Your RSVP has been updated to \"Yes\"", flash[:notice]
    assert_nil assigns(:owner_name)
  end

  def test_update_from_guest_from_email
    current_user_is :mkr_student
    members(:mkr_student).mark_attending!(meetings(:f_mentor_mkr_student))
    assert members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    program = users(:mkr_student).program
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).never

    get :update_from_guest, params: { :id => meetings(:f_mentor_mkr_student).id, :attending => MemberMeeting::ATTENDING::NO, :all_meetings => "true", email: "true"}
    assert_match "Your RSVP has been updated to \"No\"", flash[:notice]
    meetings(:f_mentor_mkr_student).reload
    assert_false members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::EMAIL, meetings(:f_mentor_mkr_student).member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
  end

  def test_update_from_guest_for_recurring_meeting_from_email
    current_user_is :mkr_student
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    daily_meeting_2 = meeting.occurrences[7]
    program = meeting.program
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      put :update_from_guest, xhr: true, params: { :id => meeting.id, :attending => MemberMeeting::ATTENDING::YES, :current_occurrence_time => daily_meeting_2.start_time, email: "true"}
    end
    student_member_meeting_response = meeting.member_meeting_responses.find_by(meeting_occurrence_time: daily_meeting_2
      .start_time)
    assert MemberMeeting::RSVP_CHANGE_SOURCE::EMAIL, student_member_meeting_response.rsvp_change_source
  end

  def test_update_from_guest_from_email_without_login
    current_program_is :albers
    members(:mkr_student).mark_attending!(meetings(:f_mentor_mkr_student), attending: MemberMeeting::ATTENDING::NO)
    assert_false members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    program = users(:mkr_student).program
    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)

    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).once
    get :update_from_guest, params: { :id => meetings(:f_mentor_mkr_student).id, :member_id => members(:mkr_student).id, :attending => MemberMeeting::ATTENDING::YES, :all_meetings => "true", email: "true"}
    assert_equal "Your RSVP has been updated to \"Yes\". <a class=\"nickname\" title=\"Good unique name\" href=\"/p/albers/members/3\">Good unique name</a> will be notified about the update.", flash[:notice]
    meetings(:f_mentor_mkr_student).reload
    assert members(:mkr_student).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::EMAIL, meetings(:f_mentor_mkr_student).member_meetings.find_by(member_id: members(:mkr_student).id).rsvp_change_source
  end

  def test_update_from_guest_for_deleted_meeting
    current_user_is :mkr_student
    meetings(:f_mentor_mkr_student).false_destroy!

    browser = get_new_browser
    @controller.stubs(:browser).returns(browser)
    program = users(:mkr_student).program
    @controller.expects(:track_sessionless_activity_for_ei).with(EngagementIndex::Activity::RSVP_YES_MEETING, members(:mkr_student), members(:mkr_student).organization, {user: members(:mkr_student).user_in_program(program), program: program, browser: browser}).never
    get :update_from_guest, params: { :id => meetings(:f_mentor_mkr_student).id, :attending => MemberMeeting::ATTENDING::NO, :all_meetings => "true"}
    assert_equal "The meeting you are trying to access does not exist.", flash[:error]
  end

  ##############################################################################
  # MANAGE MENTORING AND CALENDAR SESSIONS
  ##############################################################################

  def test_calendar_sessions_initialise_percentage_change
    program = programs(:albers)
    time = Time.now.utc + 2.days

    m1 = create_meeting(start_time: time, end_time: time + 30.minutes, force_non_group_meeting: true)
    m1.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m1.complete!

    m2 = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    m2.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)

    m3 = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    m3.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m3.cancel!

    m4 = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    m4.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)

    meetings = Meeting.accepted_meetings.non_group_meetings.includes([{:members => [:users, :profile_picture]}, :survey_answers])

    MeetingsFilterService.any_instance.stubs(:get_filtered_meeting_ids).returns([[m3.id , m4.id], [m1.id, m2.id]])
    MeetingsFilterService.any_instance.stubs(:filters_count).returns(2)
    MeetingsFilterService.any_instance.stubs(:current_program).returns(program)

    @controller.send(:get_filtered_flash_meetings)

    assert_equal assigns(:percentage), 0

    MeetingsFilterService.any_instance.stubs(:get_filtered_meeting_ids).returns([[m3.id], [m1.id, m2.id]])
    @controller.send(:get_filtered_flash_meetings)

    assert_equal assigns(:percentage), -50
  end

  def test_calendar_sessions_get_flash_meetings
    time = Time.now.utc + 2.days

    m1 = create_meeting(start_time: time, end_time: time + 30.minutes, force_non_group_meeting: true)
    m1.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m1.complete!

    m2 = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    m2.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)

    m3 = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    m3.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m3.cancel!

    m4 = create_meeting(start_time: 50.minutes.ago, end_time: 20.minutes.ago, force_non_group_meeting: true)
    m4.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    meetings = Meeting.accepted_meetings.non_group_meetings.includes([{:members => [:users, :profile_picture]}, :survey_answers])

    @controller.send(:get_flash_meetings, meetings)
    cancelled_meetings = meetings.where(state: Meeting::State::CANCELLED)
    completed_meetings = meetings.where(state: Meeting::State::COMPLETED)
    overdue_meetings = meetings.past.where(state: nil)

    assert_equal cancelled_meetings.to_a, assigns(:meeting_hash)[:cancelled_meetings].to_a
    assert_equal completed_meetings.to_a, assigns(:meeting_hash)[:completed_meetings].to_a
    assert_equal overdue_meetings.to_a, assigns(:meeting_hash)[:overdue_meetings].to_a
    assert_equal meetings.to_a, assigns(:meeting_hash)[:scheduled_meetings].to_a
  end

  def test_should_not_fetch_mentoring_sessions_if_calendar_feature_disabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_admin)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)
    assert_permission_denied do
      get :mentoring_sessions
    end
  end

  def test_should_not_fetch_calendar_sessions_if_calendar_feature_disabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    current_user_is users(:f_admin)
    assert_permission_denied do
      get :calendar_sessions
    end
  end

  def test_should_not_fetch_calendar_sessions_if_non_admin_is_accessing
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_mentor)

    assert_permission_denied do
      get :calendar_sessions
    end
  end

  def test_xls_calendar_sessions_export
    Meeting.expects(:get_meeting_ids_by_conditions).with({:not_cancelled=>true, program_id: programs(:albers).id, :active=>true}).returns([1, 2, 6])

    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_admin)

    get :calendar_sessions, params: { :format => 'xls'}
    assert_response :success
  end

  def test_xls_calendar_sessions_export_denied
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    current_user_is users(:f_mentor)

    assert_permission_denied do
      get :calendar_sessions, params: { :format => 'xls'}
    end
  end

  def test_calendar_sessions_dashboard_filters_all
    ReportsFilterService.stubs(:program_created_date).once.returns("something")
    ReportsFilterService.stubs(:dashboard_upcoming_end_date).once.returns("something else")
    ReportsFilterService.stubs(:date_to_string).with("something", "something else").returns("01/10/2015 - 03/16/2019")

    current_user_is users(:f_admin)
    get :calendar_sessions, params: { dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::ALL}
    assert_equal Meeting::ReportTabs::SCHEDULED, assigns(:tab)
    assert_equal Date.strptime("01/10/2015", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:from_date_range)
    assert_equal Date.strptime("03/16/2019", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:to_date_range)
  end

  def test_calendar_sessions_dashboard_filters_upcoming
    ReportsFilterService.stubs(:dashboard_upcoming_start_date).once.returns("something")
    ReportsFilterService.stubs(:dashboard_upcoming_end_date).once.returns("something else")
    ReportsFilterService.stubs(:date_to_string).with("something", "something else").returns("01/10/2015 - 03/16/2019")

    current_user_is users(:f_admin)
    get :calendar_sessions, params: { dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::UPCOMING}
    assert_equal Meeting::ReportTabs::SCHEDULED, assigns(:tab)
    assert_equal Date.strptime("01/10/2015", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:from_date_range)
    assert_equal Date.strptime("03/16/2019", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:to_date_range)
  end

  def test_calendar_sessions_dashboard_filters_past
    ReportsFilterService.stubs(:program_created_date).once.returns("something")
    ReportsFilterService.stubs(:dashboard_past_meetings_date).once.returns("something else")
    ReportsFilterService.stubs(:date_to_string).with("something", "something else").returns("01/10/2015 - 03/16/2019")

    current_user_is users(:f_admin)
    get :calendar_sessions, params: { dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::PAST}
    assert_equal Meeting::ReportTabs::SCHEDULED, assigns(:tab)
    assert_equal Date.strptime("01/10/2015", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:from_date_range)
    assert_equal Date.strptime("03/16/2019", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:to_date_range)
  end

  def test_calendar_sessions_dashboard_filters_completed
    ReportsFilterService.stubs(:program_created_date).once.returns("something")
    ReportsFilterService.stubs(:dashboard_past_meetings_date).once.returns("something else")
    ReportsFilterService.stubs(:date_to_string).with("something", "something else").returns("01/10/2015 - 03/16/2019")

    current_user_is users(:f_admin)
    get :calendar_sessions, params: { dashboard_filters: MeetingsController::CalendarSessionConstants::DashboardFilter::COMPLETED}
    assert_equal Meeting::ReportTabs::COMPLETED, assigns(:tab)
    assert_equal Date.strptime("01/10/2015", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:from_date_range)
    assert_equal Date.strptime("03/16/2019", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:to_date_range)
  end

  def test_should_not_fetch_mentoring_sessions_if_non_admin_is_accessing
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)
    current_user_is users(:f_mentor)

    assert_permission_denied do
      get :mentoring_sessions
    end
  end

  def test_filter_mentoring_calendar_based_on_type
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    time = Time.now.utc.change(:usec => 0)
    start_time = time - 7.days
    end_time = time + 1.day
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    recurring_meeting_count = Meeting.recurrent_meetings([meeting], get_merged_list: true, get_occurrences_between_time: true, start_time: start_time.to_date.to_time, end_time: (end_time.to_date.to_time + 1.day)).count

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true).returns(meetings(:f_mentor_mkr_student, :student_2_not_req_mentor, :f_mentor_mkr_student_daily_meeting).map(&:id))
    current_user_is :f_admin
    post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(start_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(end_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}" } }
    assert_response :success
    assert_equal recurring_meeting_count + 2, assigns(:meetings).count
    assert_equal recurring_meeting_count + 2, assigns(:ordered_meetings).count
    assert_equal Meeting::ReportTabs::SCHEDULED, assigns(:tab)
    assert_equal start_time.to_date, assigns(:from_date_range)
    assert_equal end_time.to_date, assigns(:to_date_range)
    assert_equal 0, assigns(:filters_count)
  end

  def test_filter_mentoring_calendar_should_show_accepted_meetings
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    time = Time.now.utc.change(:usec => 0)
    start_time = time - 7.days
    end_time = time + 1.day
    meeting = meetings(:f_mentor_mkr_student)
    meeting_request = MeetingRequest.last
    meeting_request.update_attributes!(status: AbstractRequest::Status::REJECTED)
    meeting.meeting_request_id = meeting_request.id
    meeting.save!
    upcoming_meeting, past_meeting = Meeting.recurrent_meetings([meetings(:f_mentor_mkr_student_daily_meeting)], get_occurrences_between_time: true, start_time: start_time.to_date.to_time, end_time: (end_time.to_date.to_time + 1.day))

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true).returns(meetings(:f_mentor_mkr_student, :student_2_not_req_mentor, :f_mentor_mkr_student_daily_meeting).map(&:id))
    current_user_is :f_admin
    post :mentoring_sessions, xhr: true, params: { tab: Meeting::ReportTabs::UPCOMING, filters: { date_range: "#{(start_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(end_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}" } }
    assert_response :success
    assert_equal upcoming_meeting.count, assigns(:meetings).count
    assert_equal upcoming_meeting.count, assigns(:ordered_meetings).count
    assert_equal Meeting::ReportTabs::UPCOMING, assigns(:tab)
    assert_equal 0, assigns(:filters_count)
    assert_equal start_time.to_date, assigns(:from_date_range)
    assert_equal end_time.to_date, assigns(:to_date_range)
  end

  def test_filter_calendar_session_should_show_accepted_meetings
    programs(:org_primary).enable_feature(FeatureName::CALENDAR)

    time = 50.minutes.ago
    start_time = time
    end_time = time + 30.minutes
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    meeting_request = MeetingRequest.last
    meeting_request.update_attributes!(status: AbstractRequest::Status::REJECTED)
    meeting.meeting_request_id = meeting_request.id
    meeting.save!

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: programs(:albers).id, active: true).returns(meetings(:past_calendar_meeting, :completed_calendar_meeting, :cancelled_calendar_meeting).map(&:id))
    current_user_is :f_admin
    post :calendar_sessions, xhr: true
    assert_response :success
    assert_equal 3, assigns(:meetings).count
    assert_equal 3, assigns(:ordered_meetings).count
    assert_equal meetings(:cancelled_calendar_meeting, :completed_calendar_meeting, :past_calendar_meeting), assigns(:meetings)
  end

  def test_to_check_search_query_is_escaped
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    time = Time.current.change(usec: 0)
    start_time = time - 7.days
    end_time = time + 1.day
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    recurring_meeting_count = Meeting.recurrent_meetings([meeting], get_merged_list: true, get_occurrences_between_time: true, start_time: start_time.to_date.to_time, end_time: (end_time.to_date.to_time + 1.day)).count

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true, :"attendees.id" => 0).returns([])
    current_user_is :f_admin
    assert_nothing_raised do
      post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(start_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(end_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}", mentoring_session: { attendee: "/" } } }
    end
    assert_response :success
    assert_equal 0, assigns(:meetings).count
    assert_equal 0, assigns(:ordered_meetings).count
    assert_equal 1, assigns(:filters_count)
    assert_equal start_time.to_date, assigns(:from_date_range)
    assert_equal end_time.to_date, assigns(:to_date_range)
  end

  def test_mentoring_session_with_group_meeting_disabled
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    time = Time.current.change(usec: 0)
    start_time = time - 7.days
    end_time = time + 1.day
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    recurring_meeting_count = Meeting.recurrent_meetings([meeting], get_merged_list: true, get_occurrences_between_time: true, start_time: start_time.to_date.to_time, end_time: (end_time.to_date.to_time + 1.day)).count

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true).returns(meetings(:f_mentor_mkr_student, :student_2_not_req_mentor, :f_mentor_mkr_student_daily_meeting).map(&:id))
    current_user_is :f_admin
    post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(start_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(end_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}" } }
    assert_response :success
    assert_equal recurring_meeting_count+2, assigns(:meetings).count
    assert_equal recurring_meeting_count+2, assigns(:ordered_meetings).count
    assert_equal start_time.to_date, assigns(:from_date_range)
    assert_equal end_time.to_date, assigns(:to_date_range)
  end

  def test_mentoring_session_with_group_meeting_disabled_and_consider_mentoring_mode
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    program.update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)

    Timecop.freeze do
      time = Time.current.change(usec: 0)
      start_time = time - 7.days
      end_time = time + 1.day
      meeting = meetings(:f_mentor_mkr_student_daily_meeting)
      recurring_meeting_count = Meeting.recurrent_meetings([meeting], { get_merged_list: true, get_occurrences_between_time: true, start_time: start_time.to_date.to_time, end_time: (end_time.to_date.to_time+1.day) } ).count

      Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true).returns(meetings(:f_mentor_mkr_student, :student_2_not_req_mentor, :f_mentor_mkr_student_daily_meeting).map(&:id))
      current_user_is :f_admin
      post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(start_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(end_time.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}" } }
      assert_response :success
      assert_equal recurring_meeting_count + 2, assigns(:meetings).count
    end
  end

  def test_filter_mentoring_calendar_report_data_based_on_period_without_type
    program = programs(:psg)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    Meeting.expects(:get_meeting_ids_by_conditions).with( { not_cancelled: true, program_id: program.id, active: true } ).returns(meetings(:psg_mentor_psg_student, :past_psg_mentor_psg_student, :upcoming_psg_mentor_psg_student).map(&:id))
    current_user_is :psg_admin
    post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(Time.now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}" } }
    assert_response :success

    range = "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(Time.now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}".split("-").collect do |date|
      Date.strptime(date.strip, MeetingsHelper::DateRangeFormat.call).to_date
    end
    from_date_range, to_date_range = range[0], range[1]
    from_time = from_date_range.is_a?(Date) ? from_date_range.to_time : from_date_range
    to_time = (to_date_range.is_a?(Date) ? to_date_range.to_time : to_date_range) + 1.day
    meetings = Meeting.accepted_meetings.group_meetings.where(program_id: program.id)
    recurrent_meetings = Meeting.recurrent_meetings(meetings, { get_merged_list: true, get_occurrences_between_time: true, start_time: from_time.utc, end_time: to_time.utc } )
    meetings = recurrent_meetings.sort { |a, b|  b[:current_occurrence_time].to_time.utc <=> a[:current_occurrence_time].to_time.utc }
    assert_equal meetings, assigns(:meetings)
  end

  def test_filter_mentoring_sessions_data_based_on_period_and_attendee
    program = programs(:psg)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true, :"attendees.id" => members(:psg_student1).id).returns(meetings(:psg_mentor_psg_student, :past_psg_mentor_psg_student, :upcoming_psg_mentor_psg_student).map(&:id))
    current_user_is :psg_admin
    post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(2.days.from_now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}", mentoring_session: { attendee: "studa psg<stud1@psg.com>" } } }
    assert_response :success
    assert_equal 1, assigns(:meetings).count
    assert_false assigns(:meetings).first.is_a?(DisplayMentoringSessionReport)
    assert_equal 1, assigns(:filters_count)
    assert_match /table.*id.*mentoring_sessions_and_slots_tabl/, response.body
    assert_match /td.*mentoring_sessions_type/, response.body
    assert_match /i.*title.*Meeting/, response.body
  end

  def test_should_not_show_other_program_slots_and_meetings
    program = programs(:psg)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    Meeting.expects(:get_meeting_ids_by_conditions).with(not_cancelled: true, program_id: program.id, active: true).returns(meetings(:psg_mentor_psg_student, :past_psg_mentor_psg_student, :upcoming_psg_mentor_psg_student).map(&:id))
    current_user_is :psg_admin
    post :mentoring_sessions, xhr: true, params: { filters: { date_range: "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(2.days.from_now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}" } }
    assert_response :success

    range = "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(2.days.from_now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}".split("-").collect do |date|
      Date.strptime(date.strip, MeetingsHelper::DateRangeFormat.call).to_date
    end
    from_date_range, to_date_range = range[0], range[1]
    from_time = from_date_range.is_a?(Date) ? from_date_range.to_time : from_date_range
    to_time   = (to_date_range.is_a?(Date) ? to_date_range.to_time : to_date_range) + 1.day
    meetings = Meeting.accepted_meetings.group_meetings.where(program_id: program.id)
    recurrent_meetings = Meeting.recurrent_meetings(meetings, { get_merged_list: true, get_occurrences_between_time: true, start_time: from_time.utc, end_time: to_time.utc } )
    meetings = recurrent_meetings.sort { |a, b|  b[:current_occurrence_time].to_time.utc <=> a[:current_occurrence_time].to_time.utc }
    assert_equal meetings, assigns(:ordered_meetings)
    assert_equal 1, assigns(:ordered_meetings).count
  end

  def test_csv_export_for_mentoring_sessions
    Meeting.expects(:get_meeting_ids_by_conditions).with({:not_cancelled=>true, program_id: programs(:albers).id, :active=>true}).returns([1, 2, 6])
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    current_user_is users(:f_admin)

    get :mentoring_sessions, params: { :format => 'csv',
      :filters => {:date_range => "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(2.days.from_now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}"
    }}
    assert_response :success

    range = "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(2.days.from_now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}".split("-").collect do |date|
      Date.strptime(date.strip, MeetingsHelper::DateRangeFormat.call).to_date
    end

    from_date_range, to_date_range = range[0], range[1]
    from_time = from_date_range.is_a?(Date) ? from_date_range.to_time : from_date_range
    to_time   = (to_date_range.is_a?(Date) ? to_date_range.to_time : to_date_range) + 1.day
    meetings = Meeting.accepted_meetings.group_meetings.where(:program_id => programs(:albers).id)
    upcoming_meetings, archived_meetings = Meeting.recurrent_meetings(meetings, {get_occurrences_between_time: true, start_time: from_time.utc, end_time: to_time.utc})
    recurrent_meetings = upcoming_meetings + archived_meetings
    meetings = recurrent_meetings.sort { |a, b|  b[:current_occurrence_time].to_time.utc <=> a[:current_occurrence_time].to_time.utc }

    assert assigns(:is_csv_request)
    assert_equal meetings, assigns(:ordered_meetings)
    assert_nil assigns(:mentor_feedback_survey_questions)
    assert_nil assigns(:mentee_feedback_survey_questions)
  end

  def test_pdf_export_for_mentoring_sessions
    Meeting.expects(:get_meeting_ids_by_conditions).with({:not_cancelled=>true, program_id: programs(:albers).id, :active=>true}).returns([1, 2, 6])
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    current_user_is users(:f_admin)

    Theme.any_instance.stubs(:css?).returns(false) # Wicked PDF tries to fetch css by sending http request which fails in test.
    get :mentoring_sessions, params: { :format => 'pdf',
      :filters => {:date_range => "#{(1.week.ago.to_date).strftime(MeetingsHelper::DateRangeFormat.call)} - #{(2.days.from_now.to_date).strftime(MeetingsHelper::DateRangeFormat.call)}",
    }}

    assert_response :success

    assert_false assigns(:is_csv_request)
    assert_equal "Mentoring Calendar Report", assigns(:title)
    assert_nil assigns(:mentor_feedback_survey_questions)
    assert_nil assigns(:mentee_feedback_survey_questions)
  end

  def test_calendar_rsvp
    token = '3ohe4aeu7q0n6zjm1b0lbmvhro1v-s0zr6t9oieqhqm0vmnfm2'
    timestamp = '1351248513'
    signature = '303611ee8b73ea66858ee6c248c7fbf40377e72c6702453e5486a03285e35fde'
    credentials = { token: token, timestamp: timestamp, signature: signature }

    m1 = meetings(:upcoming_calendar_meeting)
    mm1 = member_meetings(:member_meetings_13)
    non_recurring_response = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nMETHOD:REPLY\nBEGIN:VEVENT\nDTSTART:#{DateTime.localize(m1.start_time.utc, format: :ics_full_time)}\nDTEND:#{DateTime.localize(m1.end_time.utc, format: :ics_full_time)}\nDTSTAMP:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nORGANIZER;CN=Apollo Services:mailto:calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}\n @testmg.realizegoal.com\nUID:meeting_20171218T112713@chronus.com\nATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=DECLINED;CN=Arun K\n umar N;X-NUM-GUESTS=0:mailto:robert@example.com\nCREATED:#{DateTime.localize(m1.created_at.utc, format: :ics_full_time)}\nDESCRIPTION:Message description\,\nLAST-MODIFIED:#{DateTime.localize(m1.updated_at.utc, format: :ics_full_time)}\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:as\nTRANSP:OPAQUE\nEND:VEVENT\nEND:VCALENDAR"

    assert_equal MemberMeeting::ATTENDING::YES, mm1.attending
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    post :calendar_rsvp, params: credentials.merge("body-calendar" => non_recurring_response, "To" => "Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>")
    assert_equal MemberMeeting::ATTENDING::NO, mm1.reload.attending

    post :calendar_rsvp, params: { "body-calendar" => non_recurring_response, "To" => "Apollo Services <calendar-assistant-dev+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>"}
    assert_response 403
    assert_equal "Invaid signature", @response.body


    post :calendar_rsvp, params: credentials.merge("body-calendar" => non_recurring_response, "To" => "Apollo Services <random+#{Meeting.send(:encryptor).encrypt(m1.id)}@testmg.realizegoal.com>")
    assert_response 200
    assert_equal "Mail Received But Rejected", @response.body
  end

  def test_update_meeting_notification_channel_for_sync_message
    current_organization_is :org_primary
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now)

    @request.env['HTTP_X_GOOG_CHANNEL_ID'] = "channelId"
    @request.env['HTTP_X_GOOG_RESOURCE_ID'] = "resourceId"
    @request.env['HTTP_X_GOOG_RESOURCE_STATE'] = MeetingsController::CalendarSyncResourceState::SYNC

    Meeting.expects("start_rsvp_sync_#{channel.id}").never
    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(false)

    post :update_meeting_notification_channel

    assert_nil channel.reload.last_notification_received_on
  end

  def test_update_meeting_notification_channel_for_no_change_message
    current_organization_is :org_primary
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now)

    @request.env['HTTP_X_GOOG_CHANNEL_ID'] = "channelId"
    @request.env['HTTP_X_GOOG_RESOURCE_ID'] = "resourceId"
    @request.env['HTTP_X_GOOG_RESOURCE_STATE'] = MeetingsController::CalendarSyncResourceState::NOT_EXISTS

    Meeting.expects("start_rsvp_sync_#{channel.id}").never
    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(false)

    post :update_meeting_notification_channel

    assert_nil channel.reload.last_notification_received_on
  end

  def test_update_meeting_notification_channel_for_change_message
    current_organization_is :org_primary

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: current_time)

    @request.env['HTTP_X_GOOG_CHANNEL_ID'] = "channelId"
    @request.env['HTTP_X_GOOG_RESOURCE_ID'] = "resourceId"
    @request.env['HTTP_X_GOOG_RESOURCE_STATE'] = MeetingsController::CalendarSyncResourceState::EXISTS

    api = mock()
    api.stubs(:perform_rsvp_sync).with(current_time, channel).returns(nil)
    Calendar::GoogleApi.stubs(:new).returns(api)
    Calendar::GoogleApi.any_instance.stubs(:perform_rsvp_sync).with(current_time, channel).returns(nil)
    Meeting.expects("start_rsvp_sync_#{channel.id}").with(current_time).once
    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(false)

    post :update_meeting_notification_channel

    first_notification_time = channel.reload.last_notification_received_on
    assert_not_nil first_notification_time

    current_time = current_time + 10.minutes
    Time.stubs(:now).returns(current_time)

    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(true)
    Meeting.expects("start_rsvp_sync_#{channel.id}").with(current_time).never

    post :update_meeting_notification_channel

    second_notification_time = channel.reload.last_notification_received_on
    assert_not_nil second_notification_time
  end

  def test_update_meeting_notification_channel_for_change_message_with_sync_running
    current_organization_is :org_primary

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: current_time)

    @request.env['HTTP_X_GOOG_CHANNEL_ID'] = "channelId"
    @request.env['HTTP_X_GOOG_RESOURCE_ID'] = "resourceId"
    @request.env['HTTP_X_GOOG_RESOURCE_STATE'] = MeetingsController::CalendarSyncResourceState::EXISTS

    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(true)
    Meeting.expects("start_rsvp_sync_#{channel.id}").with(current_time).never

    post :update_meeting_notification_channel

    assert_not_nil channel.reload.last_notification_received_on
  end

  def test_update_meeting_notification_channel_for_unmatched_channel_id
    current_organization_is :org_primary
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now)

    @request.env['HTTP_X_GOOG_CHANNEL_ID'] = "differentChannelId"
    @request.env['HTTP_X_GOOG_RESOURCE_ID'] = "resourceId"
    @request.env['HTTP_X_GOOG_RESOURCE_STATE'] = MeetingsController::CalendarSyncResourceState::EXISTS

    Meeting.expects("start_rsvp_sync_#{channel.id}").never
    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(false)

    post :update_meeting_notification_channel

    assert_nil channel.reload.last_notification_received_on
  end

  def test_update_meeting_notification_channel_for_unmatched_resource_id
    current_organization_is :org_primary
    channel = CalendarSyncNotificationChannel.create!(channel_id: "channelId", resource_id: "resourceId", expiration_time: Time.now)

    @request.env['HTTP_X_GOOG_CHANNEL_ID'] = "channelId"
    @request.env['HTTP_X_GOOG_RESOURCE_ID'] = "differentResourceId"
    @request.env['HTTP_X_GOOG_RESOURCE_STATE'] = MeetingsController::CalendarSyncResourceState::EXISTS

    Meeting.expects("start_rsvp_sync_#{channel.id}").never
    Meeting.stubs(:is_rsvp_sync_currently_running?).with(channel.id).returns(false)

    post :update_meeting_notification_channel

    assert_nil channel.reload.last_notification_received_on
  end

  def test_get_calendar_sync_instructions_page
    current_program_is :albers

    get :get_calendar_sync_instructions_page

    assert_response :success
  end

  def test_get_calendar_sync_instructions_page_with_feature_disabled
    current_program_is :albers

    @controller.stubs(:can_access_feature?).returns(false)

    get :get_calendar_sync_instructions_page

    assert_response :success
  end

  def test_edit_state
    current_user_is :f_mentor
    m = meetings(:f_mentor_mkr_student)
    m.update_attributes!({:group => nil, :mentee_id => users(:mkr_student).member.id})
    get :edit_state, xhr: true, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time, :src => EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_AREA }
    member_meeting = m.member_meetings.where(:member_id => users(:f_mentor).member.id).first
    assert assigns(:meeting), m
    assert assigns(:current_occurrence_time), m.occurrences.first.start_time
    assert assigns(:attendee), member_meeting.other_members.collect(&:name).to_sentence
    assert assigns(:src), EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_AREA
  end

  def test_update_state
    current_user_is :f_mentor
    m = meetings(:f_mentor_mkr_student)
    current_user = users(:f_mentor)

    time_now = Time.now
    Time.stubs(:now).returns(time_now)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING_STATE).once
    get :update_state, xhr: true, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time, :meeting_state => Meeting::State::COMPLETED, :src => EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_AREA }

    assert assigns(:meeting), m
    assert assigns(:current_occurrence_time), m.occurrences.first.start_time
    assert assigns(:member_meeting_id), m.member_meetings.where(:member_id => users(:f_mentor).member.id).first
    assert assigns(:meeting_feedback_survey), m.program.get_meeting_feedback_survey_for_user_in_meeting(current_user, m)
    assert_equal time_now.to_i, m.reload.state_marked_at.to_i

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING_STATE).once
    get :update_state, xhr: true, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time, :meeting_state => Meeting::State::CANCELLED, :src => EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_AREA }
    assert assigns(:meeting), m
    assert assigns(:current_occurrence_time), m.occurrences.first.start_time
    assert assigns(:member_meeting_id), m.member_meetings.where(:member_id => users(:f_mentor).member.id).first
    assert assigns(:meeting_feedback_survey), m.program.get_meeting_feedback_survey_for_user_in_meeting(current_user, m)
  end

  def test_ics_api_access_success
    m = members(:f_mentor)
    assert_equal 0, m.calendar_sync_count

    @controller.expects(:check_browser).never
    current_program_is :albers

    get :ics_api_access, params: { calendar_api_key: m.calendar_api_key, format: :ics }
    assert_response :success
    assert_equal 1, m.reload.calendar_sync_count
    assert_equal 6, assigns(:meetings).count
    assert @response.body.match(/METHOD:PUBLISH/)[0].present?
    assert @response.body.match(/#{m.name}/)[0].present?
    assert_equal "text/calendar", @response.content_type

    # non-time meeting should also be included in the list
    time = 2.days.from_now
    meeting = create_meeting(force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    get :ics_api_access, params: { calendar_api_key: m.calendar_api_key, format: :ics }
    assert_response :success
    assert_equal 2, m.reload.calendar_sync_count
    assert_equal 7, assigns(:meetings).count
  end

  def test_mini_popup
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    student_user = users(:f_student)
    mentor_user = users(:f_mentor)
    mentor_member = mentor_user.member

    calendar_setting = student_user.program.calendar_setting
    calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    mentor_member.update_attributes!(will_set_availability_slots: true)
    mentor_user.user_setting.update_attributes(max_meeting_slots: 20)
    mentor_user.reload

    slot1 = mentor_member.mentoring_slots.first
    slot_start_time = (Time.current + 1.month).beginning_of_month + 3.days + 2.hours
    slot_end_time = slot_start_time + 1.hour
    slot1.update_attributes!(start_time: slot_start_time, end_time: slot_end_time)
    slot2 = create_mentoring_slot(
      member: mentor_member,
      location: "Bangalore",
      start_time: slot_start_time + 3.days,
      end_time: slot_start_time + 3.days + 2.hours,
      repeats: MentoringSlot::Repeats::NONE,
      repeats_on_week: nil
    )

    current_user_is student_user
    get :mini_popup, xhr: true, params: { member_id: mentor_member.id}
    assert_response :success
    assert_equal mentor_member, assigns(:member)
    assert_equal 2, assigns(:available_slots).size
    assert_equal "Good unique name available at -", assigns(:available_slots)[0][:title]
    assert_equal "Good unique name available at Bangalore", assigns(:available_slots)[1][:title]
  end

  def test_mini_popup_when_program_doesnot_allow_mentor_to_configure_slots
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_student)

    member = members(:f_mentor)
    slot1 = member.mentoring_slots.first
    slot_start_time = Time.now + 3.days + 2.hours
    slot_end_time = slot_start_time + 1.hour
    slot1.update_attributes!(:start_time => slot_start_time, :end_time => slot_end_time)

    slot2 = create_mentoring_slot(:member => member, :location => "Bangalore",
      :start_time => slot_start_time + 3.days, :end_time => slot_start_time + 3.days + 2.hours,
      :repeats => MentoringSlot::Repeats::NONE, :repeats_on_week => nil)

    get :mini_popup, xhr: true, params: { :member_id => members(:f_mentor).id}
    assert_response :success

    assert_equal member, assigns(:member)
    assert_nil assigns(:available_slots)
    assert_match /Propose Another Timeslot/, ActionController::Base.helpers.strip_tags(response.body).squish
    assert_no_match(/Propose other times/, ActionController::Base.helpers.strip_tags(response.body).squish)
  end

  def test_index_create_meeting_for_mentor_disabled
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    current_program = programs(:albers)
    current_program.calendar_setting.update_attribute(:allow_create_meeting_for_mentor, false)
    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)
    get :index, params: { :group_id => groups(:mygroup).id}
    assert_equal [{:current_occurrence_time => m.occurrences.first.start_time, :meeting => m}], assigns(:meetings_to_be_held)
    assert_equal  [{:current_occurrence_time => meetings(:f_mentor_mkr_student).occurrences.first,  :meeting => meetings(:f_mentor_mkr_student)}], assigns(:archived_meetings)
    assert_false assigns(:can_current_user_create_meeting)
  end

  def test_index_from_connection_home_page_widget
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    current_program = programs(:albers)

    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)
    get :index, params: { :group_id => groups(:mygroup).id, :from_connection_home_page_widget => true}
    assert_equal [{:current_occurrence_time => m.occurrences.first.start_time, :meeting => m}], assigns(:meetings_to_be_held)
    assert_equal [{:current_occurrence_time => m.occurrences.first.start_time, :meeting => m}], assigns(:meetings_to_show)
    assert assigns(:from_connection_home_page_widget)

    assert assigns(:can_access_tabs)
    assert_false assigns(:show_meetings)
    assert assigns(:page_controls_allowed)
  end

  def test_select_meeting_slot
    current_user_is users(:f_student)

    program = programs(:albers)

    start_time = "2016-12-19T10:30:00Z"
    end_time = "2016-12-19T11:30:00Z"

    get :select_meeting_slot, xhr: true, params: { :mentor_id => members(:f_mentor).id, :start_time => start_time, :end_time => end_time, :location => "Hyderabad"}

    assert_response :success

    assert_equal members(:f_mentor), assigns(:mentor)
    assert_equal program.get_calendar_slot_time, assigns(:allowed_individual_slot_duration)
    assert_equal program.calendar_setting.slot_time_in_minutes.zero?, assigns(:unlimited_slot)
    assert_equal 3600, assigns(:slot_duration).to_i
    assert_equal "Hyderabad", assigns(:new_meeting).location
  end

  def test_mini_popup_should_give_only_for_current_and_next_month
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is users(:f_student)
    calendar_setting = users(:f_student).program.calendar_setting
    calendar_setting.update_attributes!(allow_mentor_to_configure_availability_slots: true)
    calendar_setting.update_attributes!(slot_time_in_minutes: 60)
    member = members(:f_mentor)

    users(:f_mentor).user_setting.update_attributes(:max_meeting_slots => 20)
    users(:f_mentor).reload

    member.update_attributes!(will_set_availability_slots: true)
    slot1 = member.mentoring_slots.first

    current_time = Time.now
    Time.stubs(:now).returns(current_time.beginning_of_month + 2.days)

    slot_start_time = Time.now + 3.days + 2.hours
    slot_end_time = slot_start_time + 1.hour
    slot1.update_attributes!(:start_time => slot_start_time, :end_time => slot_end_time)

    slot2 = create_mentoring_slot(:member => member, :location => "Bangalore",
      :start_time => slot_start_time + 3.days, :end_time => slot_start_time + 3.days + 2.hours,
      :repeats => MentoringSlot::Repeats::NONE, :repeats_on_week => nil)

    slot3 = create_mentoring_slot(:member => member, :location => "Seattle",
      :start_time => slot_start_time.next_month.beginning_of_day, :end_time => slot_start_time.next_month.beginning_of_day + 2.hours,
      :repeats => MentoringSlot::Repeats::NONE, :repeats_on_week => nil)

    slot4 = create_mentoring_slot(:member => member, :location => "Hyderabad",
      :start_time => slot_start_time + 14.days, :end_time => slot_start_time + 14.days + 30.minutes,
      :repeats => MentoringSlot::Repeats::NONE, :repeats_on_week => nil)

    get :mini_popup, xhr: true, params: { :member_id => members(:f_mentor).id}
    assert_response :success

    assert_equal 3, assigns(:available_slots).size
    assert_equal [], assigns(:available_slots).select{|s| s[:location] == "Hyderabad"}
  end

  def test_new_quick_meeting_from_request_meeting_popup
    current_user_is :f_student
    current_organization_is :org_primary

    start_time = (Time.now.utc + 2.days).beginning_of_day + 8.hours
    end_time = start_time + 30.minutes

    get :new, xhr: true, params: { :mentor_id => members(:f_mentor).id, :start_time => start_time, :end_time => end_time, :request_meeting_popup => true}
    assert_response :success

    assert assigns(:request_meeting_popup).present?
    assert assigns(:profile_questions).nil?
  end

  def test_new_quick_meeting_from_quick_meeting_popup
    current_user_is :f_student
    current_organization_is :org_primary

    start_time = (Time.now.utc + 2.days).beginning_of_day + 8.hours
    end_time = start_time + 30.minutes

    get :new, xhr: true, params: { :mentor_id => members(:f_mentor).id, :start_time => start_time, :end_time => end_time, :quick_meeting_popup => true}
    assert_response :success

    assert assigns(:quick_meeting_popup).present?
    assert assigns(:profile_questions).nil?
  end

  def test_create_without_group
    current_user_is :mkr_student
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_SIDE_PANE
    src = EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MEETING_REQUEST, {:context_place => src}).once
    @controller.expects(:finished_chronus_ab_test).times(2)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).never
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      assert_difference  'members(:f_mentor).reload.meetings.size', 1 do
        assert_difference  'members(:mkr_student).reload.meetings.size', 1 do
          post :create, xhr: true, params: { :common_form => true, :outside_group => "true",src: src,  :meeting => {:topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:f_mentor).id.to_s], :date => (Time.now + 1.year).strftime("%B %d, %Y"), :ei_src => ei_src}}
          assert_response :success

          meeting = Meeting.last
          assert_equal members(:mkr_student).id, meeting.mentee_id
        end
      end
    end
    assert assigns(:guidance_experiment).is_a?(Experiments::GuidancePopup)
    assert assigns(:popular_categories_experiment).is_a?(Experiments::PopularCategories)
    assert assigns(:track_ab_tests_data)
  end

  def test_create_with_blank_attendees_inadequate_time
    program = programs(:albers)
    c = program.calendar_setting
    c.advance_booking_time = 24
    c.save!
    current_user_is :f_student
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_SIDE_PANE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).never
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      assert_difference  'members(:f_mentor).meetings.size', 0 do
        assert_difference  'members(:mkr_student).meetings.size', 0 do
          post :create, xhr: true, params: { :common_form => true, :meeting => {:topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2000", :ei_src => ei_src}}
          assert_response :success
        end
      end
    end
    assert_equal "Appointments must be reserved #{programs(:albers).get_allowed_advance_slot_booking_time} hours in advance.", assigns(:error_flash)
  end

  def test_create_with_blank_attendees_inadequate_time_for_zero_hours
    program = programs(:albers)
    assert_equal 0, program.calendar_setting.advance_booking_time
    current_user_is :f_student
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_SIDE_PANE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).never
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      assert_difference  'members(:f_mentor).meetings.size', 0 do
        assert_difference  'members(:mkr_student).meetings.size', 0 do
          post :create, xhr: true, params: { :common_form => true, :meeting => {:topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2000", :ei_src => ei_src}}
          assert_response :success
        end
      end
    end
    assert_equal program.get_allowed_advance_slot_booking_time, 0
    assert_equal "#{CustomizedTerm::TermType::MEETING_TERM}s cannot be created in the past", assigns(:error_flash)
  end

  def test_create_originating_from_quick_connect
    program = programs(:albers)
    template = program.mailer_templates.where(:uid => MeetingCreationNotificationToOwner.mailer_attributes[:uid]).first
    if template.present?
      template.update_attribute(:enabled, true)
      assert template.enabled?
    end
    current_user_is :f_mentor
    ei_src = EngagementIndex::Src::CreateGroupMeeting::MENTORING_AREA_SIDE_PANE
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::CREATE_GROUP_MEETING, {:context_place => ei_src}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      assert_difference  'members(:f_mentor).meetings.size', 1 do
        assert_difference  'members(:mkr_student).meetings.size', 1 do
          post :create, params: { :common_form => true, :ei_src => ei_src, :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2025"}}
        end
      end
    end
    assert_nil assigns(:guidance_experiment)
    assert_nil assigns(:popular_categories_experiment)
    assert_nil assigns(:track_ab_tests_data)
    assert_redirected_to member_path(members(:f_mentor), :tab => MembersController::ShowTabs::AVAILABILITY, :src => MeetingsController::SourceParams::QUICK_CONNECT)
  end

  def test_ics_api_access_with_removed_user
    m = members(:f_mentor)
    meeting = create_meeting(
      members: [members(:f_mentor), members(:mkr_student)],
      owner_id: members(:mkr_student).id
    )
    members(:mkr_student).destroy

    current_program_is :albers
    get :ics_api_access, params: { calendar_api_key: m.calendar_api_key, format: :ics }
    assert_response :success
    assert assigns(:meetings).present?
    assert @response.body.match(/METHOD:PUBLISH/)[0].present?
    assert @response.body.match(/Removed User/)[0].present?
    assert_equal "text/calendar", @response.content_type
  end

  def test_minipopup_with_non_time_meeting
    current_user_is users(:f_student)
    member = members(:f_mentor)
    member.update_attributes!(will_set_availability_slots: false)

    get :mini_popup, xhr: true, params: { :member_id => member.id}
    assert_response :success
  end

  def test_validate_propose_slot
    current_user_is users(:f_student)
    member = members(:f_mentor)

    program = programs(:albers)
    program.calendar_setting.update_attribute(:advance_booking_time, 2)
    users(:f_mentor).user_setting.update_attributes(:max_meeting_slots => 20)
    users(:f_mentor).reload

    current_time = Time.now
    Time.stubs(:now).returns(current_time)
    proposed_date = (current_time+2.day).strftime("%B %d, %Y")
    start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, "07:00 am", "08:00 am")

    proposed_slots_hash = {1 => {date: proposed_date, startTime: "07:00 am", endTime: "08:00 am", location: "Bangalore"}}

    Member.any_instance.stubs(:not_having_any_meeting_during_interval?).with(start_time, end_time).returns(true)

    get :validate_propose_slot, xhr: true, params: { :mentor_id => member.id, slotDetails: proposed_slots_hash}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "", json_response["error_flash"]
    assert json_response["valid"]
    assert_equal json_response["slot_detail"], "feature.meetings.content.selected_proposed_slot_detail".translate(slot_timing: DateTime.localize(start_time, format: :full_display_with_zone_without_month), slot_minutes: ((end_time-start_time).to_i)/(1.minute.to_i))
  end

  def test_validate_propose_slot_past_time
    current_user_is users(:f_student)
    member = members(:f_mentor)

    program = programs(:albers)
    program.calendar_setting.update_attribute(:advance_booking_time, 2)

    current_time = Time.now
    Time.stubs(:now).returns(current_time)
    proposed_date = (current_time-2.day).strftime("%B %d, %Y")
    start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, "07:00 am", "08:00 am")

    proposed_slots_hash = {1 => {date: proposed_date, startTime: "07:00 am", endTime: "08:00 am", location: "Bangalore"}}

    get :validate_propose_slot, xhr: true, params: { :mentor_id => member.id, slotDetails: proposed_slots_hash}

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "Meeting times cannot be in the past.", json_response["error_flash"]
    assert_false json_response["valid"]
  end

  def test_validate_propose_slot_proposed_before_advance_time
    member = members(:f_mentor)
    program = programs(:albers)
    program.calendar_setting.update_attribute(:advance_booking_time, 2)

    Timecop.freeze(Time.current.beginning_of_day) do
      proposed_date = Time.current.strftime("%B %d, %Y")
      proposed_start_time = Time.current.strftime("%I:%M %p")
      proposed_end_time = (Time.current + 2.hours).strftime("%I:%M %p")
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, proposed_start_time, proposed_end_time)

      current_user_is :f_student
      proposed_slots_hash = { 1 => { date: proposed_date, startTime: proposed_start_time, endTime: proposed_end_time, location: "Bangalore" } }
      get :validate_propose_slot, xhr: true, params: { :mentor_id => member.id, slotDetails: proposed_slots_hash}
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal "Meeting to Good unique name should be requested 2 hours in advance.", json_response["error_flash"]
      assert_false json_response["valid"]
    end
  end

  def test_validate_propose_slot_mentor_having_meeting_during_proposed_time
    member = members(:f_mentor)
    program = programs(:albers)
    program.calendar_setting.update_attribute(:advance_booking_time, 2)

    Timecop.freeze(Time.current.beginning_of_day) do
      proposed_date = (Time.current + 2.days).strftime("%B %d, %Y")
      proposed_start_time = "01:00 AM"
      proposed_end_time = "02:00 AM"
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, proposed_start_time, proposed_end_time)

      Member.any_instance.stubs(:not_having_any_meeting_during_interval?).with(start_time, end_time).returns(false)
      proposed_slots_hash = { 1 => { date: proposed_date, startTime: proposed_start_time, endTime: proposed_end_time, location: "Bangalore" } }
      current_user_is :f_student
      get :validate_propose_slot, xhr: true, params: { :mentor_id => member.id, slotDetails: proposed_slots_hash}
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal "Good unique name is not available for meeting during proposed time. Please select some other time.", json_response["error_flash"]
      assert_false json_response["valid"]
    end
  end

  def test_validate_propose_slot_zero_slots_remaining
    member = members(:f_mentor)
    program = programs(:albers)
    program.calendar_setting.update_attribute(:advance_booking_time, 2)

    Timecop.freeze do
      proposed_date = (Time.current + 2.days).strftime("%B %d, %Y")
      proposed_start_time = "01:00 AM"
      proposed_end_time = "02:00 AM"
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, proposed_start_time, proposed_end_time)

      Member.any_instance.stubs(:not_having_any_meeting_during_interval?).with(start_time, end_time).returns(true)
      proposed_slots_hash = { 1 => { date: proposed_date, startTime: proposed_start_time, endTime: proposed_end_time, location: "Bangalore" } }
      current_user_is :f_student
      get :validate_propose_slot, xhr: true, params: { mentor_id: member.id, slotDetails: proposed_slots_hash}
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_match(/Good unique name has already reached the limit for the number of meetings in.*and is not available for meetings/, json_response["error_flash"])
      assert_false json_response["valid"]
    end
  end

  def test_validate_propose_slot_mentee_meeting_limit_reached
    member = members(:f_mentor)
    program = programs(:albers)
    program.calendar_setting.update_attribute(:advance_booking_time, 2)

    Timecop.freeze do
      proposed_date = (Time.current + 2.days).strftime("%B %d, %Y")
      proposed_start_time = "01:00 AM"
      proposed_end_time = "02:00 AM"
      start_time, end_time = MentoringSlot.fetch_start_and_end_time(proposed_date, proposed_start_time, proposed_end_time)

      User.any_instance.stubs(:is_max_capacity_user_reached?).with(start_time).returns(false)
      User.any_instance.stubs(:is_student_meeting_limit_reached?).with(start_time).returns(true)
      User.any_instance.stubs(:is_student_meeting_request_limit_reached?).returns(false)
      Member.any_instance.stubs(:not_having_any_meeting_during_interval?).with(start_time, end_time).returns(true)

      proposed_slots_hash = { 1 => {date: proposed_date, startTime: proposed_start_time, endTime: proposed_end_time, location: "Bangalore" } }
      current_user_is :f_student
      get :validate_propose_slot, xhr: true, params: { mentor_id: member.id, slotDetails: proposed_slots_hash}
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_match "You cannot send any more meeting requests as you have reached the limit for the number of meetings", json_response["error_flash"]
      assert_false json_response["valid"]
    end
  end

  def test_create_non_time_meeting
    current_user_is users(:f_student)
    member = members(:f_mentor)
    member.update_attributes!(will_set_availability_slots: false)
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(true)

    time = "2025-03-01 18:15:00".to_time
    Time.stubs(:now).returns(time)

    users(:f_mentor).user_setting.update_attributes!(:max_meeting_slots => 20)

    proposed_slots_hash = {1 => {date: "December 01, 2016", startTime: "07:00 am", endTime: "08:00 am", location: "Bangalore"}, 2 => {date: "December 01, 2016", startTime: "07:00 am", endTime: "09:00 am", location: "Hyderabad"}}
    UserPreferenceService.any_instance.stubs(:find_available_favorite_users).returns([users(:f_mentor), users(:f_admin)])

    assert_nil members(:f_student).availability_not_set_message
    src = EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MEETING_REQUEST, {:context_place => src}).once
    @controller.expects(:finished_chronus_ab_test).times(2)
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    assert_difference 'MeetingProposedSlot.count', 2 do
      post :create, xhr: true, params: { :meeting => {topic: "Test Topic", description: "Gen Description", :attendee_ids => [members(:f_mentor).id.to_s], :proposedSlots => proposed_slots_hash, menteeAvailabilityText: "available on weekdays"}, "non_time_meeting" => "true", "quick_meeting" => "true", src: src}
    end

    assert_equal "available on weekdays", members(:f_student).reload.availability_not_set_message
    assert assigns(:is_non_time_meeting)
    assert assigns(:is_quick_meeting)
    assert_equal [users(:f_mentor).id, users(:f_admin).id], assigns(:favorite_user_ids)
    assert_equal "2025-03-16 18:30:00".to_time.utc, assigns(:meeting).start_time
    assert_false assigns(:meeting).calendar_time_available
    assert assigns(:meeting).active?
    assert assigns(:guidance_experiment).is_a?(Experiments::GuidancePopup)
    assert assigns(:popular_categories_experiment).is_a?(Experiments::PopularCategories)
    assert assigns(:track_ab_tests_data)
  end

  def test_create_non_time_meeting_with_unlimmited_slot_time
    current_user_is users(:f_student)
    member = members(:f_mentor)
    member.update_attributes!(will_set_availability_slots: false)
    user = users(:f_student)
    program = user.program
    calendar_setting = program.calendar_setting
    calendar_setting.slot_time_in_minutes = 0
    calendar_setting.save!
    Program.any_instance.stubs(:skip_and_favorite_profiles_enabled?).returns(false)

    User.any_instance.stubs(:is_max_capacity_user_reached?).returns(false)
    src = EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MEETING_REQUEST, {:context_place => src}).once
    @controller.expects(:finished_chronus_ab_test).times(2)

    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).never
    assert_difference "Meeting.count" do
      post :create, xhr: true, params: { :meeting => {topic: "Test Topic", description: "Gen Description", :attendee_ids => [members(:f_mentor).id.to_s]},
        "non_time_meeting" => "true", "quick_meeting" => "true", src: src}
    end

    assert assigns(:is_non_time_meeting)
    assert assigns(:is_quick_meeting)
    assert_equal 1.hour, assigns(:meeting).duration
    assert_false assigns(:meeting).calendar_time_available
    assert assigns(:meeting).active?
    assert_nil assigns(:favorite_user_ids)
    assert assigns(:guidance_experiment).is_a?(Experiments::GuidancePopup)
    assert assigns(:popular_categories_experiment).is_a?(Experiments::PopularCategories)
    assert assigns(:track_ab_tests_data)
  end

  def test_show
    current_user_is :f_mentor
    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)

    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :show, xhr: true, params: { :id => m.id, :current_occurrence_time => m.occurrences.last, outside_group: "true"}
      end
    end
    assert_response :success
    assert_template '_show'
    assert_equal Meeting.last, assigns(:meeting)
    assert_equal assigns(:outside_group), true
  end


  def test_show_open_edit_popup_as_false
    current_user_is :f_mentor
    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)
    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(false)
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :show, xhr: true, params: { :id => m.id, :current_occurrence_time => m.occurrences.last, open_edit_popup: true }
      end
    end
    assert_response :success
    assert_template '_show'
    assert_equal Meeting.last, assigns(:meeting)
    assert_false assigns(:open_edit_popup)
    assert_equal "You do not have the permission to change the meeting time. Please reach out to your mentors to change the meeting time.", flash[:error]
  end

  def test_show_open_edit_popup_as_true
    current_user_is :f_mentor
    m = create_meeting(:start_time => 10.minutes.since, :end_time => 15.minutes.since)
    Meeting.any_instance.stubs(:can_be_edited_by_member?).returns(true)
    assert_difference 'RecentActivity.count' do
      assert_difference 'Connection::Activity.count' do
        get :show, xhr: true, params: { :id => m.id, :current_occurrence_time => m.occurrences.last, open_edit_popup: true }
      end
    end
    assert_response :success
    assert_template '_show'
    assert_equal Meeting.last, assigns(:meeting)
    assert assigns(:open_edit_popup)
  end


  def test_show_for_meeting_area_mentor_view
    current_user_is :f_mentor
    m = meetings(:f_mentor_mkr_student)
    ei_src = EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_FLASH_MEETING_AREA, {:context_place => ei_src}).never
    get :show, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time, :ei_src => EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_LISTING}
    assert_response :success
    assert_template 'show'
    current_user = users(:f_mentor)
    assert_equal m, assigns(:meeting)
    assert assigns(:current_occurrence_time), m.occurrences.first.start_time
    assert assigns(:back_link), {:link => session[:back_url] }
    assert assigns(:meeting_feedback_survey), m.program.get_meeting_feedback_survey_for_user_in_meeting(current_user, m)
    assert_equal m.group, assigns(:group)
    assert_false assigns(:is_admin_view)
    assert_equal EngagementIndex::Src::AccessFlashMeetingArea::PROVIDE_FEEDBACK_MEETING_LISTING.to_s, assigns(:src)
  end

  def test_show_accept_flash_meeting
    current_user_is :f_mentor
    time = Time.now.utc + 2.days
    m1 = create_meeting(start_time: time, end_time: time + 30.minutes, force_non_group_meeting: true)
    m1.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m1.complete!
    get :show, xhr: true, params: { id: m1.id, current_occurrence_time: m1.occurrences.first.start_time, src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE, format: 'html' }
    assert_equal EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_ACCEPTANCE, assigns(:src_path)
  end

  def test_show_for_meeting_area_mentor_view_invalid_occurrence_time
    current_user_is :f_mentor
    m = meetings(:f_mentor_mkr_student)
    get :show, params: { id: m.id, current_occurrence_time: m.occurrences.first.start_time+1.minutes}
    assert_response :success
    assert_template 'show'
    current_user = users(:f_mentor)
    assert_equal m, assigns(:meeting)
    assert assigns(:current_occurrence_time), m.occurrences.first.start_time
    assert assigns(:back_link), {:link => session[:back_url] }
    assert assigns(:meeting_feedback_survey), m.program.get_meeting_feedback_survey_for_user_in_meeting(current_user, m)
    assert_equal m.group, assigns(:group)
    assert_false assigns(:is_admin_view)
  end

  def test_show_for_meeting_area_admin_view
    current_user_is :f_admin
    m = meetings(:f_mentor_mkr_student)
    ei_src = EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_FLASH_MEETING_AREA, {context_place: ei_src}).never
    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'Connection::Activity.count' do
        get :show, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time, ei_src: ei_src}
      end
    end
    assert_response :success
    assert_template 'show'
    assert_equal m, assigns(:meeting)
    assert assigns(:current_occurrence_time), m.occurrences.first.start_time
    assert assigns(:back_link), {:link => session[:back_url] }
    assert_equal m.group, assigns(:group)
    assert assigns(:is_admin_view)
    assert_nil assigns(:meeting_feedback_survey)
  end

  def test_show_for_meeting_area_non_member
    current_user_is :f_student
    m = meetings(:f_mentor_mkr_student)
    ei_src = EngagementIndex::Src::AccessFlashMeetingArea::MEETING_REQUEST_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::ACCESS_FLASH_MEETING_AREA, {context_place: ei_src}).never
    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'Connection::Activity.count' do
        assert_permission_denied do
          get :show, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time, :ei_src => ei_src}
        end
      end
    end
  end

  def test_show_for_meeting_area_admin_view_diff_program
    current_user_is :f_admin
    m =  meetings(:upcoming_psg_mentor_psg_student)
    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'Connection::Activity.count' do
        assert_raise ActiveRecord::RecordNotFound do
          get :show, params: { :id => m.id, :current_occurrence_time => m.occurrences.first.start_time}
        end
      end
    end
  end

  def test_index_for_admin
    current_user_is :f_admin
    group = groups(:mygroup)
    old_last_activity_at = group.last_activity_at
    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'Connection::Activity.count' do
        get :index, xhr: true, params: { group_id: group.id}
      end
    end
    assert_response :success
    assert_equal old_last_activity_at, group.reload.last_activity_at
    assert_equal assigns(:ei_src), EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
  end

  def test_destroy_non_group_meetings
    time_now = Time.now.utc.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    time = time_now + 2.days
    current_user_is :f_mentor
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.expects(:remove_calendar_event).once

    assert_difference 'Meeting.count', -1 do
      assert_difference 'ActionMailer::Base.deliveries.size', 2 do
        delete :destroy, xhr: true, params: { :id => meeting.id}
      end
    end
    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Cancelled: General Topic", email.subject
    assert_match "has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting.end_time.strftime("%I:%M %P"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_false meeting.reload.active?
  end

  def test_destroy_all_occurrences
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    time_now = Time.now
    Time.stubs(:local).returns(time_now)
    update_recurring_meeting_start_end_date(meeting, meeting.occurrences.first.start_time, meeting.occurrences.last.end_time, options = {duration: 30.minutes})

    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.expects(:remove_calendar_event).once

    assert_difference 'Meeting.count', -1 do
      assert_difference 'ActionMailer::Base.deliveries.size', 2 do
        delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::ALL, :current_occurrence_time => meeting.occurrences.second.start_time}
      end
    end

    email = ActionMailer::Base.deliveries.last
    email_content = get_html_part_from(email)
    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Cancelled: Arbit Daily Topic", email.subject
    assert_match "has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting.end_time.strftime("%B %_d, %Y"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_false meeting.reload.active?
  end

  def test_destroy_all_following_occurrences_from_first_occurrences
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    time_now = Time.now
    Time.stubs(:local).returns(time_now)
    update_recurring_meeting_start_end_date(meeting, meeting.occurrences.first.start_time, meeting.occurrences.last.end_time, options = {duration: 30.minutes})
    assert_difference 'Meeting.count', -1 do
      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::ALL, :current_occurrence_time => meeting.occurrences.first.start_time}
      end
    end

    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Cancelled: Arbit Daily Topic", email.subject
    assert_match "has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting.end_time.strftime("%B %_d, %Y"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert_false meeting.reload.active?
  end

  def test_destroy_all_following_occurrences_from_a_middle_occurrences_without_cal_sync
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    time_now = Time.now
    Time.stubs(:local).returns(time_now)
    meeting_occurrences = meeting.occurrences
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    Meeting.expects(:handle_update_calendar_event).never

     assert_difference 'meeting.reload.occurrences.count', -3 do
      assert_difference 'ActionMailer::Base.deliveries.size', 1 do
        delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::FOLLOWING, :current_occurrence_time => meeting.occurrences[8].start_time}
      end
    end

    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Cancelled: Arbit Daily Topic", email.subject
    assert_match "has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting_occurrences[8].start_time.strftime("%B %d, %Y"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end

    assert_equal meeting.occurrences, (meeting_occurrences - meeting_occurrences[8..10])
    assert meeting.reload.active?
  end

  def test_destroy_all_following_occurrences_from_a_middle_occurrences
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    time_now = Time.now
    Time.stubs(:local).returns(time_now)
    meeting_occurrences = meeting.occurrences
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.expects(:handle_update_calendar_event).once

    assert_difference 'meeting.reload.occurrences.count', -3 do
      assert_difference 'ActionMailer::Base.deliveries.size', 2 do
        delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::FOLLOWING, :current_occurrence_time => meeting.occurrences[8].start_time}
      end
    end

    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Updated: Arbit Daily Topic", email.subject
    assert_match "This event has been updated", email_content
    assert_match meeting.topic, email_content
    time = MeetingScheduleStringifier.new(meeting).stringify
    start_time = DateTime.localize(meeting.occurrences.first.in_time_zone(members(:f_mentor).get_valid_time_zone), format: :short)
    assert_match time, email_content
    assert_match start_time, email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end

    assert_equal meeting.occurrences, (meeting_occurrences - meeting_occurrences[8..10])
    assert meeting.reload.active?
  end

  def test_destroy_one_past_occurrence
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    meeting_occurrences = meeting.occurrences

    assert_difference 'meeting.reload.occurrences.count', -1 do
      assert_difference 'Meeting.count', 0 do
        assert_difference 'ActionMailer::Base.deliveries.size', 0 do
          delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::CURRENT, :current_occurrence_time => meeting.occurrences.second.start_time}
        end
      end
    end
    assert_equal meeting.reload.occurrences, (meeting_occurrences - [meeting_occurrences.second])
    assert meeting.reload.active?
  end

  def test_destroy_one_future_occurrence_without_cal_sync
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    meeting_occurrences = meeting.occurrences
    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    Meeting.expects(:handle_update_calendar_event).never

    assert_difference 'meeting.reload.occurrences.count', -1 do
      assert_difference 'Meeting.count', 0 do
        assert_difference 'ActionMailer::Base.deliveries.size', 1 do
          assert_difference 'RecentActivity.count' do
            assert_difference 'Connection::Activity.count' do
              delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::CURRENT, :current_occurrence_time => meeting.occurrences.last.start_time}
            end
          end
        end
      end
    end

    assert_equal meeting.reload.occurrences, (meeting_occurrences - [meeting_occurrences.last])
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY

    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Cancelled: Arbit Daily Topic", email.subject
    assert_match "has cancelled the meeting", email_content
    assert_match meeting.topic, email_content
    assert_match meeting_occurrences.last.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting_occurrences.last.end_time.strftime("%B %d, %Y"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert meeting.reload.active?
  end

  def test_destroy_one_future_occurrence
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    assert meeting.active?
    meeting_occurrences = meeting.occurrences
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.expects(:handle_update_calendar_event).once

    assert_difference 'meeting.reload.occurrences.count', -1 do
      assert_difference 'Meeting.count', 0 do
        assert_difference 'ActionMailer::Base.deliveries.size', 2 do
          assert_difference 'RecentActivity.count' do
            assert_difference 'Connection::Activity.count' do
              delete :destroy, xhr: true, params: { :id => meetings(:f_mentor_mkr_student_daily_meeting).id, :group_id => meetings(:f_mentor_mkr_student_daily_meeting).group.id, :delete_option => Meeting::EditOption::CURRENT, :current_occurrence_time => meeting.occurrences.last.start_time}
            end
          end
        end
      end
    end

    assert_equal meeting.reload.occurrences, (meeting_occurrences - [meeting_occurrences.last])
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY

    email = ActionMailer::Base.deliveries.last

    email_content = get_html_part_from(email)

    assert_equal email.to.first, users(:mkr_student).email
    assert_equal "Updated: Arbit Daily Topic", email.subject
    assert_match "This event has been updated", email_content
    assert_match meeting.topic, email_content
    assert_match meeting_occurrences.first.start_time.strftime("%B %d, %Y"), email_content
    assert_match meeting_occurrences.first.end_time.strftime("%B %d, %Y"), email_content
    meeting.members.each do |g|
      assert_match g.name, email_content
    end
    assert meeting.reload.active?
  end

  def test_new_connection_widget_meeting_for_future_meeting
    current_user_is :f_mentor
    group = groups(:mygroup)

    get :new_connection_widget_meeting, xhr: true, params: { :group_id => group.id}

    assert_response :success
    assert_false assigns(:is_past_meeting)
    assert_equal group, assigns(:new_meeting).group
  end

  def test_new_connection_widget_meeting_for_past_meeting
    current_user_is :f_mentor
    group = groups(:mygroup)

    get :new_connection_widget_meeting, xhr: true, params: { :group_id => group.id, :is_past_meeting => "true"}

    assert_response :success
    assert assigns(:is_past_meeting)
    assert_equal group, assigns(:new_meeting).group
  end

  def test_get_destroy_popup
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student_daily_meeting)

    assert_difference 'Connection::Activity.count' do
      assert_difference 'RecentActivity.count' do
        get :get_destroy_popup, xhr: true, params: { :id => meeting.id, :current_occurrence_time => meeting.occurrences.last.start_time, :group_id => meeting.group.id, from_connection_home_page_widget: true}
      end
    end
    assert_response :success
    assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY
    assert_template '_delete_options'
    assert_equal meeting, assigns(:meeting)
    assert assigns(:from_connection_home_page_widget)
  end

  def test_update_date_for_recurrent_meeting
    m = meetings(:f_mentor_mkr_student_daily_meeting)
    old_meeting_attributes = m.attributes
    current_user_is :f_mentor
    old_start_time = m.start_time
    current_occurrence_time = m.occurrences.last(2).first.start_time
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => EngagementIndex::Src::UpdateMeeting::MEETING_AREA}).once
    assert_emails 1 do
      assert_difference 'Connection::Activity.count', 1 do
        assert_difference 'RecentActivity.count', 1 do
          assert_difference 'MemberMeetingResponse.count', -1 do
            put :update, xhr: true, params: { :id => m.id, ei_src: EngagementIndex::Src::UpdateMeeting::MEETING_AREA, :edit_option => Meeting::EditOption::CURRENT, :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
              :start_time_of_day => (old_start_time + 30.minutes).strftime('%I:%M %p'), :end_time_of_day => (old_start_time + 1.hour).strftime('%I:%M %p'), :current_occurrence_time => current_occurrence_time.to_s, :attendee_ids => [members(:f_mentor).id, members(:mkr_student).id], current_occurrence_date: DateTime.localize(current_occurrence_time, format: :full_display_no_time), date: DateTime.localize((current_occurrence_time + 1.day), format: :full_display_no_time)}, group_id: meetings(:f_mentor_mkr_student).group.id}
          end
        end
      end
    end
    m.reload
    recent_activity = RecentActivity.last
    # assert_equal RecentActivity.last.action_type, RecentActivityConstants::Type::MEETING_UPDATED
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal m.group, groups(:mygroup)
    assert_equal m.topic, old_meeting_attributes["topic"]
    assert_equal m.description, old_meeting_attributes["description"]
    assert_time_string_equal(m.start_time, old_start_time)
    new_meeting = Meeting.last
    assert_equal_unordered new_meeting.members, [members(:f_mentor), members(:mkr_student)]
    assert_equal new_meeting.group, groups(:mygroup)
    assert_equal new_meeting.topic, "Genmax Topic"
    assert_equal new_meeting.description, "Gen Description"
    assert_time_string_equal(new_meeting.start_time, current_occurrence_time + 1.day + 30.minutes)
    assert_equal "Updated: #{new_meeting.topic}", ActionMailer::Base.deliveries.last.subject
    assert_equal Meeting.last, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::MEETING_UPDATED, recent_activity.action_type
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, new_meeting.member_meetings.find_by(member_id: members(:f_mentor)).rsvp_change_source
    email = ActionMailer::Base.deliveries.last
    assert_nil get_text_part_from(email).gsub("\n", " ").match(/Propose Time/)
    assert members(:f_mentor), assigns(:meeting).updated_by_member
  end

  def test_update_date_for_non_recurrent_meeting
    current_user_is :f_mentor
    st = Time.current.beginning_of_day + 2.days
    en = st + 1.hour
    meetings(:f_mentor_mkr_student).update_attribute(:group_id, nil)
    meetings(:f_mentor_mkr_student).update_attribute(:calendar_event_id, "calendar_event_id")
    meetings(:f_mentor_mkr_student).update_attribute(:mentee_id, members(:mkr_student).id)
    m = meetings(:f_mentor_mkr_student).reload

    api = mock()
    api.stubs(:update_calendar_event).returns(nil)
    Calendar::GoogleApi.stubs(:new).returns(api)
    Meeting.any_instance.stubs(:can_be_synced?).returns(true)
    Meeting.any_instance.stubs(:can_send_update_email_notification?).returns(true)
    Meeting.expects(:handle_update_calendar_event).once

    mentor_member_meeting = m.member_meetings.where(member_id: members(:f_mentor)).first
    student_member_meeting = m.member_meetings.where(member_id: members(:mkr_student)).first
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      put :update, xhr: true, params: { :id => meetings(:f_mentor_mkr_student).id , :ei_src => ei_src, :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
        :start_time_of_day => st.strftime('%I:%M %p'), :end_time_of_day => en.strftime('%I:%M %p'), current_occurrence_date: DateTime.localize((st - 1.day), format: :full_display_no_time), date: DateTime.localize(st, format: :full_display_no_time)}, outside_group: "true"}
    end

    assert_template 'update'
    m = meetings(:f_mentor_mkr_student).reload
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_nil m.group
    assert_equal m.topic, "Genmax Topic"
    assert_equal m.description, "Gen Description"
    assert_time_string_equal st, m.start_time
    assert_time_string_equal en, m.end_time
    assert_equal MemberMeeting::ATTENDING::NO_RESPONSE, student_member_meeting.reload.attending
    assert_equal MemberMeeting::ATTENDING::YES, mentor_member_meeting.reload.attending
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, m.member_meetings.find_by(member_id: members(:f_mentor)).rsvp_change_source
  end

  def test_update_date_for_non_recurrent_meeting_from_meeting_area
    current_user_is :f_mentor
    st = Time.current.beginning_of_day + 2.days
    en = st + 1.hour
    meetings(:f_mentor_mkr_student).update_attribute(:group_id, nil)
    meetings(:f_mentor_mkr_student).update_attribute(:mentee_id, members(:mkr_student).id)
    meetings(:f_mentor_mkr_student).reload
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => EngagementIndex::Src::UpdateMeeting::MEETING_AREA}).once

    Meeting.any_instance.stubs(:can_be_synced?).returns(false)
    Meeting.any_instance.stubs(:can_send_update_email_notification?).returns(true)

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      post :update, params: { :id => meetings(:f_mentor_mkr_student).id , :meeting => {:topic => "Genmax Topic", :description => "Gen Description",
        :start_time_of_day => st.strftime('%I:%M %p'), :end_time_of_day => en.strftime('%I:%M %p'), current_occurrence_date: DateTime.localize((st - 1.day), format: :full_display_no_time), date: DateTime.localize(st, format: :full_display_no_time)}, meeting_area: "true", ei_src: EngagementIndex::Src::UpdateMeeting::MEETING_AREA
      }
    end

    m = meetings(:f_mentor_mkr_student).reload
    assert_redirected_to meeting_path(m, current_occurrence_time: Meeting.recurrent_meetings([m], get_merged_list: true).first[:current_occurrence_time], :edit_time_only => false, meeting_updated: true, ei_src: EngagementIndex::Src::AccessFlashMeetingArea::MEETING_AREA)
    assert_equal_unordered m.members, [members(:f_mentor), members(:mkr_student)]
    assert_nil m.group
    assert_equal m.topic, "Genmax Topic"
    assert_equal m.description, "Gen Description"
    assert_time_string_equal st, m.start_time
    assert_time_string_equal en, m.end_time
    assert_nil assigns(:meetings_to_be_held)
    assert_nil assigns(:archived_meetings)
    assert_match "The changes to this meeting were successfully saved and the attendees were notified about the update.", flash[:notice]
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, m.member_meetings.find_by(member_id: members(:f_mentor)).rsvp_change_source
  end

  def test_ics_api_render_nothing_when_no_permission_or_member_not_found
    m = members(:f_mentor)
    program = programs(:albers)
    program.enable_feature(FeatureName::CALENDAR, false)

    current_program_is program
    get :ics_api_access, params: { calendar_api_key: m.calendar_api_key, format: :ics }
    assert_blank @response.body

    m.destroy
    get :ics_api_access, params: { calendar_api_key: m.calendar_api_key, format: :ics }
    assert_blank @response.body

    get :ics_api_access, params: { calendar_api_key: "invalidApiKey", format: :ics}
    assert_blank @response.body
  end

  def test_create_past_meeting_in_group_with_calendar_settings_enabled
    program = programs(:albers)
    c = program.calendar_setting
    c.advance_booking_time = 24
    c.save!
    current_user_is :f_mentor
    src = EngagementIndex::Src::SendRequestOrOffers::QUICK_CONNECT_BOX
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::SEND_MEETING_REQUEST, {:context_place => src}).never
    @controller.expects(:finished_chronus_ab_test).never
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::RECORD_PAST_MEETING).once
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      assert_difference  'members(:f_mentor).meetings.size', 1 do
        assert_difference  'members(:mkr_student).meetings.size', 1 do
          post :create, xhr: true, params: { :common_form => true, :meeting => {:group_id => groups(:mygroup).id, :topic => "Gen Topic" ,:start_time_of_day => '08:30 am', :end_time_of_day => '09:30 am',
            :description => "Gen Description", :location => "CLT", :attendee_ids => [members(:mkr_student).id.to_s], :date => "February 25, 2000"}, past_meeting: true
          }
          assert_response :success
        end
      end
    end
    assert_nil assigns(:guidance_experiment)
    assert_nil assigns(:popular_categories_experiment)
    assert_nil assigns(:track_ab_tests_data)
    assert_nil assigns(:error_flash)
    assert_equal members(:f_mentor).meetings.last.group, groups(:mygroup)
    assert assigns(:past_meeting)
  end

  def test_update_meeting_time_from_upcoming_to_past
    current_user_is :f_mentor
    time_now = Time.current.beginning_of_day.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    meeting = create_meeting(start_time: time_now + 48.hours, end_time: time_now + 49.hours)

    #update upcoming to past meeting
    st = 100.minutes.ago
    en = 70.minutes.ago
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 0 do
      put :update, xhr: true, params: { :ei_src => ei_src, :id => meeting.id , :meeting => {:topic => "Genmax Topic", :description => "Gen Description", :start_time_of_day => st.strftime('%I:%M %p'), :end_time_of_day => en.strftime('%I:%M %p'), :date => st.strftime('%b %d, %Y'),
        :attendee_ids => [members(:f_mentor).id.to_s], :edit_option => Meeting::EditOption::ALL}, :group_id => groups(:mygroup)
      }
      assert_response :success
    end
    meeting.reload
    assert_time_string_equal(meeting.start_time, st)
    assert_time_string_equal(meeting.end_time, en)
    assert_equal [MemberMeeting::ATTENDING::YES], meeting.member_meetings.pluck(:attending).uniq
    assert_equal MemberMeeting::RSVP_CHANGE_SOURCE::APP_AUTOMATIC, meeting.member_meetings.find_by(member_id: members(:f_mentor)).rsvp_change_source
  end

  def test_update_meeting_time_from_past_to_past
    time = Time.current.beginning_of_day - 2.days
    meeting = create_meeting(start_time: time + 1.hour, end_time: time + 2.hours)

    st = time + 3.hours
    en = st + 30.minutes
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, context_place: ei_src).once
    assert_no_emails do
      current_user_is :f_mentor
      put :update, xhr: true, params: {
        id: meeting.id,
        ei_src: ei_src,
        meeting: {
          topic: "Genmax Topic",
          description: "Gen Description",
          start_time_of_day: st.strftime('%I:%M %p'),
          end_time_of_day: en.strftime('%I:%M %p'),
          date: st.strftime('%b %d, %Y'),
          attendee_ids: [members(:f_mentor).id.to_s],
          edit_option: Meeting::EditOption::ALL
        },
        group_id: groups(:mygroup)
      }
    end
    assert_response :success
    meeting.reload
    assert_time_string_equal meeting.start_time, st
    assert_time_string_equal meeting.end_time, en
  end

  def test_update_meeting_time_from_past_to_upcoming
    current_user_is :f_mentor
    time_now = Time.current.beginning_of_day.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    meeting = create_meeting(start_time: time_now - 2.hours, end_time: time_now - 1.hour)

    #update past to upcoming meeting
    st = time_now + 2.days + 100.minutes
    en = st + 30.minutes
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, {:context_place => ei_src}).once
    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      put :update, xhr: true, params: { :id => meeting.id , :ei_src => ei_src, :meeting => {:topic => "Genmax Topic", :description => "Gen Description", :start_time_of_day => st.strftime('%I:%M %p'), :end_time_of_day => en.strftime('%I:%M %p'), :date => st.strftime('%b %d, %Y'),
        :attendee_ids => [members(:f_mentor).id.to_s], :edit_option => Meeting::EditOption::ALL}, :group_id => groups(:mygroup)
      }
      assert_response :success
    end
    meeting.reload
    assert_time_string_equal(meeting.start_time, st)
    assert_time_string_equal(meeting.end_time, en)
  end

  def test_update_meeting_time_from_upcoming_to_upcoming
    user = users(:f_mentor)
    time_set = (Time.current + 2.days).beginning_of_day
    meeting = create_meeting(start_time: time_set + 1.hour, end_time: time_set + 2.hours)

    # update upcoming to upcoming meeting
    st = time_set + 200.minutes
    en = time_set + 230.minutes
    ei_src = EngagementIndex::Src::UpdateMeeting::MENTORING_AREA_MEETING_LISTING
    @controller.expects(:track_activity_for_ei).with(EngagementIndex::Activity::UPDATE_MEETING, context_place: ei_src).once
    current_user_is user
    assert_emails do
      put :update, xhr: true, params: { id: meeting.id, ei_src: ei_src,
        meeting: {
          topic: "Genmax Topic",
          description: "Gen Description",
          start_time_of_day: st.strftime('%I:%M %p'),
          end_time_of_day: en.strftime('%I:%M %p'),
          date: st.strftime('%b %d, %Y'),
          attendee_ids: [user.member_id.to_s],
          edit_option: Meeting::EditOption::ALL
        },
        group_id: groups(:mygroup)
      }
    end
    assert_response :success
    meeting.reload
    assert_time_string_equal meeting.start_time, st
    assert_time_string_equal meeting.end_time, en
  end

  def test_valid_free_slots_past_meetings_case_a
    Timecop.freeze
    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options
    start_date = Date.yesterday

    get :valid_free_slots, xhr: true, params: { past_meeting: true, partial_options: partial_options, slot_time_in_minutes: 30 }
    assert_response :success
    assert_equal 48, assigns[:localized_free_slots][:start_times_array].size
    assert_equal 48, assigns[:localized_free_slots][:end_times_array].size
    assert_nil assigns[:shortlist_slots]
    @controller.send(:localize_free_slots, @controller.send(:split_time_slot, [{start: start_date, end: start_date.tomorrow}], 30))
    assert_equal Array.new(48, 47), assigns[:indices]
    assert_false assigns[:no_slots_available]
    Timecop.return
  end

  def test_valid_free_slots_for_range_past_meetings_case_a
    Timecop.freeze
    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options
    start_date = Date.yesterday
    span = -3

    get :valid_free_slots_for_range, xhr: true, params: { past_meeting: true, partial_options: partial_options, slot_time_in_minutes: 30, pickedDate: start_date, span: span }
    assert_response :success
    assert_equal [48], assigns[:localized_free_slots].map{|k, v| v[:start_times_array].size }.uniq
    assert_equal [48], assigns[:localized_free_slots].map{|k, v| v[:end_times_array].size }.uniq
    assert_nil assigns[:shortlist_slots]
    Timecop.return
  end

  def test_valid_free_slots_past_meetings_case_b
    Timecop.freeze
    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options
    start_date = Date.yesterday

    get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 30, pickedDate: start_date }
    assert_response :success
    assert_equal 48, assigns[:localized_free_slots][:start_times_array].size
    assert_equal 48, assigns[:localized_free_slots][:end_times_array].size
    assert_nil assigns[:shortlist_slots]
    @controller.send(:localize_free_slots, @controller.send(:split_time_slot, [{start: start_date, end: start_date.tomorrow}], 30))
    assert_equal Array.new(48, 47), assigns[:indices]
    assert_false assigns[:no_slots_available]
    Timecop.return
  end

  def test_valid_free_slots_future_meetings_30_mins_duration
    Timecop.freeze
    @controller.expects(:get_slots_hash).returns(get_free_calendar_slots_for_member)

    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options

    get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 30 }
    assert_response :success
    assert_equal [3, 3, 3, 3, 8, 8, 8, 8, 8, 17, 17, 17, 17, 17, 17, 17, 17, 17], assigns[:indices]
    assert_equal ["12:00 am", "12:30 am", "01:00 am", "01:30 am", "04:00 am", "04:30 am", "05:00 am", "05:30 am", "06:00 am", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm"], assigns[:localized_free_slots][:start_times_array]
    assert_equal ["12:30 am", "01:00 am", "01:30 am", "02:00 am", "04:30 am", "05:00 am", "05:30 am", "06:00 am", "06:30 am", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm"], assigns[:localized_free_slots][:end_times_array]
    assert_false assigns[:no_slots_available]
    Timecop.return
  end

  def test_valid_free_slots_for_range_future_meetings_30_mins_duration
    time = Time.new(2018, 5, 17)
    Timecop.freeze(time) do
      @controller.expects(:get_slots_hash_for_range).returns(get_free_calendar_slots_for_member(time))

      calendar_sync_v2_common_setup
      current_user_is :f_mentor
      partial_options = get_partial_options

      get :valid_free_slots_for_range, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 30, span: 3 }
      assert_response :success
      assert_equal [[3, 3, 3, 3, 6, 6, 6], [1, 1, 10, 10, 10, 10, 10, 10, 10, 10, 10], [-1], [-1]], assigns[:indices].values
      assert_equal 0.upto(3).map{|i| time.utc.beginning_of_day + i.days}, assigns[:indices].keys
      assert_equal [["06:30 pm", "07:00 pm", "07:30 pm", "08:00 pm", "10:30 pm", "11:00 pm", "11:30 pm"], ["12:00 am", "12:30 am", "08:30 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am", "11:30 am", "12:00 pm", "12:30 pm"], [], []], assigns[:localized_free_slots].map{|k,v|v[:start_times_array]}
      assert_equal [["07:00 pm", "07:30 pm", "08:00 pm", "08:30 pm", "11:00 pm", "11:30 pm", "12:00 am"], ["12:30 am", "01:00 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am", "11:30 am", "12:00 pm", "12:30 pm", "01:00 pm"], [], []], assigns[:localized_free_slots].map{|k,v|v[:end_times_array]}
      assert_equal [false, false, true, true], assigns[:no_slots_available].values
    end
  end

  def test_valid_free_slots_future_meetings_60_mins_duration
    Timecop.freeze
    @controller.expects(:get_slots_hash).returns(get_free_calendar_slots_for_member)

    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options

    get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 60 }
    assert_response :success
    assert_equal [2, 2, 2, 6, 6, 6, 6, 14, 14, 14, 14, 14, 14, 14, 14], assigns[:indices]
    assert_equal ["12:00 am", "12:30 am", "01:00 am", "04:00 am", "04:30 am", "05:00 am", "05:30 am", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm"], assigns[:localized_free_slots][:start_times_array]
    assert_equal ["01:00 am", "01:30 am", "02:00 am", "05:00 am", "05:30 am", "06:00 am", "06:30 am", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm"], assigns[:localized_free_slots][:end_times_array]
    assert_false assigns[:no_slots_available]
    Timecop.return
  end

  def test_valid_free_slots_single_user_case
    Timecop.freeze
    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options

    get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 60 }
    assert_response :success
    assert_equal ([46] * 47), assigns[:indices]
    assert_equal ["12:00 am", "12:30 am", "01:00 am", "01:30 am", "02:00 am", "02:30 am", "03:00 am", "03:30 am", "04:00 am", "04:30 am", "05:00 am", "05:30 am", "06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am", "08:30 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am", "11:30 am", "12:00 pm", "12:30 pm", "01:00 pm", "01:30 pm", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm", "07:00 pm", "07:30 pm", "08:00 pm", "08:30 pm", "09:00 pm", "09:30 pm", "10:00 pm", "10:30 pm", "11:00 pm"], assigns[:localized_free_slots][:start_times_array]
    assert_equal ["01:00 am", "01:30 am", "02:00 am", "02:30 am", "03:00 am", "03:30 am", "04:00 am", "04:30 am", "05:00 am", "05:30 am", "06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am", "08:30 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am", "11:30 am", "12:00 pm", "12:30 pm", "01:00 pm", "01:30 pm", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm", "07:00 pm", "07:30 pm", "08:00 pm", "08:30 pm", "09:00 pm", "09:30 pm", "10:00 pm", "10:30 pm", "11:00 pm", "11:30 pm", "12:00 am"], assigns[:localized_free_slots][:end_times_array]
    assert_nil assigns[:shortlist_slots]
    Timecop.return
  end

  # group with members.size > 2
  def test_valid_free_slots_group_case
    Timecop.freeze
    current_user_is :psg_mentor1
    partial_options = get_partial_options
    group = groups(:multi_group)

    get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 60, group_id: group.id }
    assert_response :success
    assert_equal ([46] * 47), assigns[:indices]
    assert_equal ["12:00 am", "12:30 am", "01:00 am", "01:30 am", "02:00 am", "02:30 am", "03:00 am", "03:30 am", "04:00 am", "04:30 am", "05:00 am", "05:30 am", "06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am", "08:30 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am", "11:30 am", "12:00 pm", "12:30 pm", "01:00 pm", "01:30 pm", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm", "07:00 pm", "07:30 pm", "08:00 pm", "08:30 pm", "09:00 pm", "09:30 pm", "10:00 pm", "10:30 pm", "11:00 pm"], assigns[:localized_free_slots][:start_times_array]
    assert_equal ["01:00 am", "01:30 am", "02:00 am", "02:30 am", "03:00 am", "03:30 am", "04:00 am", "04:30 am", "05:00 am", "05:30 am", "06:00 am", "06:30 am", "07:00 am", "07:30 am", "08:00 am", "08:30 am", "09:00 am", "09:30 am", "10:00 am", "10:30 am", "11:00 am", "11:30 am", "12:00 pm", "12:30 pm", "01:00 pm", "01:30 pm", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm", "07:00 pm", "07:30 pm", "08:00 pm", "08:30 pm", "09:00 pm", "09:30 pm", "10:00 pm", "10:30 pm", "11:00 pm", "11:30 pm", "12:00 am"], assigns[:localized_free_slots][:end_times_array]
    assert_nil assigns[:shortlist_slots]
    Timecop.return
  end

  # CALENDAR_SYNC_V2 : uncomment this test after calling remove_invalid_slots method
  # def test_remove_invalid_slots_bypass
  #   @controller.expects(:get_slots_hash).returns(get_free_calendar_slots_for_member)
  #   @controller.expects(:validate_proposed_slots_hash).never

  #   calendar_sync_v2_common_setup
  #   current_user_is :f_mentor
  #   partial_options = get_partial_options

  #   get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 60 }
  #   assert_response :success
  # end

  # CALENDAR_SYNC_V2 : uncomment this test after calling remove_invalid_slots method
  # def test_remove_invalid_slots
  #   calendar_sync_v2_common_setup
  #   current_user_is :f_student
  #   mentor = members(:f_mentor)
  #   partial_options = get_partial_options
  #   start_date = Date.current
  #   start_time = start_date.beginning_of_day.utc + 1.hour
  #   create_meeting(start_time: start_time, end_time: start_time + 1.hour)
  #   Member.expects(:get_members_free_slots_after_meetings).returns(get_free_calendar_slots_for_member(start_date))
  #   User.any_instance.expects(:is_max_capacity_user_reached?).at_least_once.returns(false)

  #   Timecop.freeze(start_date.beginning_of_day) do
  #     get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 60, mentor_id: mentor.id, pickedDate: start_date, propose_slots: true }
  #     assert_response :success
  #     assert_equal [3, 3, 3, 3, 11, 11, 11, 11, 11, 11, 11, 11], assigns[:indices]
  #     assert_equal ["04:00 am", "04:30 am", "05:00 am", "05:30 am", "02:00 pm", "02:30 pm", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm"], assigns[:localized_free_slots][:start_times_array]
  #     assert_equal ["05:00 am", "05:30 am", "06:00 am", "06:30 am", "03:00 pm", "03:30 pm", "04:00 pm", "04:30 pm", "05:00 pm", "05:30 pm", "06:00 pm", "06:30 pm"], assigns[:localized_free_slots][:end_times_array]
  #     assert_false assigns[:no_slots_available]
  #   end
  # end

  def test_get_mandatory_times
    Timecop.freeze
    calendar_sync_v2_common_setup
    current_user_is :f_mentor
    partial_options = get_partial_options
    start_time = Time.current
    meeting = create_meeting(start_time: start_time, end_time: start_time + 1.hour)

    get :valid_free_slots, xhr: true, params: { partial_options: partial_options, slot_time_in_minutes: 60, meetingId: meeting.id, isEditForm: true, pickedDate: start_time.to_date, currentOccurrenceTime: Time.current }
    assert_response :success
    assert assigns[:trigger_no_change]
    Timecop.return
  end

  def test_validate_proposed_slots_hash
    Timecop.freeze
    calendar_sync_v2_common_setup
    current_user_is :f_student
    mentor = members(:f_mentor)
    start_date = Date.current
    start_time = start_date.beginning_of_day.utc + 1.hour

    get :validate_propose_slot, xhr: true, params: { slotDetails: {1 => {date: DateTime.localize(start_date, format: :full_display_no_time), startTime: DateTime.localize(start_time, format: :short_time_small), endTime: DateTime.localize(start_time + 1.hour, format: :short_time_small)}}, mentor_id: mentor.id }
    assert_false JSON.parse(@response.body)["valid"]
    Timecop.return
  end

  def test_edit
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)

    get :edit, params: { id: meeting.id, current_occurrence_time: meeting.occurrences.first.start_time.to_s, outside_group: "false", show_recurring_options: "false", meeting_area: "false", from_connection_home_page_widget: true}
    assert_response :success
    assert_false assigns(:outside_group)
    assert_equal meeting, assigns(:meeting)
    assert_equal meeting.group, assigns(:group)
    assert_false assigns(:unlimited_slot)
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_equal meeting.schedule.duration, assigns(:slot_duration)
    assert assigns(:from_connection_home_page_widget)
  end

  def test_edit_in_meeting_area
    current_user_is :f_mentor
    meeting = meetings(:f_mentor_mkr_student)

    get :edit, params: { id: meeting.id, current_occurrence_time: meeting.occurrences.first.start_time.to_s, outside_group: "false", show_recurring_options: "false", meeting_area: "true"}
    assert_response :success
    assert_false assigns(:outside_group)
    assert_equal meeting, assigns(:meeting)
    assert_equal meeting.group, assigns(:group)
    assert_false assigns(:unlimited_slot)
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_equal meeting.schedule.duration, assigns(:slot_duration)
    assert_false assigns(:from_connection_home_page_widget)
  end

  def test_survey_response
    meeting_setup
    current_user_is :f_admin
    get :survey_response, xhr: true, params: { id: @meeting.id, survey_id: @survey.id, user_id: @user.id, response_id: @response_id }
    assert_equal_unordered @survey.survey_questions, assigns(:questions)
    assert_equal @user, assigns(:user)
    answers = @meeting.survey_answers.select("common_answers.id, common_question_id, answer_text, common_answers.last_answered_at").index_by(&:common_question_id)
    answers.each do |key, val|
      assert_equal_hash val.attributes, assigns(:answers)[key].attributes
    end
  end

  def test_survey_response_of_removed_user
    meeting_setup
    current_user_is :f_admin

    @meeting.member_meetings.where(member_id: @user.member.id).first.update_column(:member_id, users(:rahim).member.id)
    get :survey_response, xhr: true, params: { id: @meeting.id, survey_id: @survey.id, user_id: @user.id, response_id: @response_id}
    assert_equal_unordered @survey.survey_questions, assigns(:questions)
    assert_equal @user, assigns(:user)
    answers = @meeting.survey_answers.select("common_answers.id, common_question_id, answer_text, common_answers.last_answered_at").index_by(&:common_question_id)
    answers.each do |key, val|
      assert_equal_hash val.attributes, assigns(:answers)[key].attributes
    end
  end

  private

  def meeting_setup
    @user = users(:f_mentor)
    @student = users(:mkr_student)
    @program = programs(:albers)
    time = Time.now.utc
    @meeting = create_meeting(start_time: time, end_time: time + 30.minutes, force_non_group_meeting: true)
    @meeting.complete!
    @program = programs(:albers)
    @survey = @program.get_meeting_feedback_survey_for_user_in_meeting(@user, @meeting)
    member_meeting_id = @meeting.member_meetings.where(member_id: @user.member.id).first.id
    question_id = @survey.survey_questions.pluck(:id)
    @survey.update_user_answers({question_id[0] => "Extremely satisfying", question_id[1] => "Great use of time"}, {user_id: @user.id, :meeting_occurrence_time => @meeting.occurrences.first.start_time, member_meeting_id: member_meeting_id})
    @response_id = SurveyAnswer.where(member_meeting_id: member_meeting_id).last.response_id
  end

  def get_new_browser
    Browser.new(request.headers["User-Agent"], accept_language: request.headers["Accept-Language"])
  end

  def get_partial_options
    {start_time_attributes: {name: "meeting[start_time_of_day]", class: "cjs-meeting-start-time-input"}, end_time_attributes: {name: "meeting[end_time_of_day]", class: "cjs-meeting-end-time-input"}, meeting_date_container_class: "meeting_date_container ", unlimited_slot: true}
  end

  def calendar_sync_v2_common_setup
    programs(:org_primary).enable_feature(FeatureName::CALENDAR_SYNC_V2)
  end

end