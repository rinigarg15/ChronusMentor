require_relative './../test_helper.rb'

class MentoringSlotsControllerTest < ActionController::TestCase
include MentoringSlotsHelper

  def setup
    super
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, true)
    members(:f_mentor).update_attributes!(will_set_availability_slots: true)
  end

  def test_new
    current_user_is :f_mentor
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    men = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_equal members(:f_mentor).mentoring_slots.last, men
    st = 10.minutes.since
    en = 20.minutes.since
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, true)
    get :new, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time => st, :end_time => en}}
    assert_response :success
    assert_equal assigns(:mentoring_slot_locations), ["Bhopal", "Indore", "Chennai"]

    assert_time_string_equal assigns(:mentoring_slot).start_time, st
    assert_time_string_equal assigns(:mentoring_slot).end_time, (st + 30.minutes)
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_equal st.to_i, assigns(:new_meeting).start_time.to_i
    assert_equal (st + 30.minutes).to_i, assigns(:new_meeting).end_time.to_i
    assert assigns(:can_current_user_create_meeting) #current_user is mentor, calendar feature is enabled and mentor can create meeting.
    assert assigns(:can_mark_availability_slot)
    assert_false assigns(:unlimited_slot)
  end

  def test_new_with_unlimited_slot_time
    current_user_is :f_mentor
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    men = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_equal members(:f_mentor).mentoring_slots.last, men
    st = 10.minutes.since
    en = 20.minutes.since
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, true)
    programs(:albers).calendar_setting.update_attribute(:slot_time_in_minutes, 0)
    get :new, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time => st, :end_time => en}}
    assert_response :success
    assert_equal assigns(:mentoring_slot_locations), ["Bhopal", "Indore", "Chennai"]

    assert_time_string_equal assigns(:mentoring_slot).start_time, st
    assert_time_string_equal assigns(:mentoring_slot).end_time, (st + 30.minutes)
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_equal st.to_i, assigns(:new_meeting).start_time.to_i
    assert_equal assigns(:new_meeting).end_time.to_i, (st + 10.minutes).to_i
    assert assigns(:can_current_user_create_meeting) #current_user is mentor, calendar feature is enabled and mentor can create meeting.
    assert assigns(:can_mark_availability_slot)
    assert assigns(:unlimited_slot)
  end

  def test_new_in_past_time
    current_user_is :f_mentor
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, true)
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    men = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_equal members(:f_mentor).mentoring_slots.last, men
    st = 10.minutes.ago
    en = 20.minutes.since
    get :new, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time => st, :end_time => en}}
    assert_response :success
    assert_equal assigns(:mentoring_slot_locations), ["Bhopal", "Indore", "Chennai"]

    assert_time_string_equal assigns(:mentoring_slot).start_time, st
    assert_time_string_equal assigns(:mentoring_slot).end_time, (st + 30.minutes)
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_equal st.to_i, assigns(:new_meeting).start_time.to_i
    assert_equal (st + 30.minutes).to_i, assigns(:new_meeting).end_time.to_i
    assert assigns(:can_current_user_create_meeting) #current_user is mentor, calendar feature is enabled and mentor can create meeting.
    assert_false assigns(:can_mark_availability_slot)
  end

  def test_new_with_one_hour_slot_and_mentor_can_not_create_meeting
    current_user_is :f_mentor
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, false)
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    men = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_equal members(:f_mentor).mentoring_slots.last, men
    st = 10.minutes.since
    en = 70.minutes.since
    get :new, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time => st, :end_time => en}}
    assert_response :success
    assert_equal assigns(:mentoring_slot_locations), ["Bhopal", "Indore", "Chennai"]

    assert_time_string_equal assigns(:mentoring_slot).start_time, st
    assert_time_string_equal assigns(:mentoring_slot).end_time, en
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert_equal st.to_i, assigns(:new_meeting).start_time.to_i
    assert_equal (st + 30.minutes).to_i, assigns(:new_meeting).end_time.to_i
    assert_false assigns(:can_current_user_create_meeting) #current_user is mentor, calendar feature is enabled and mentor can not create meeting
  end

  def test_create_success
    st = Time.current.beginning_of_day + 2.days
    en = st + 45.minutes
    current_user_is :f_mentor
    MentoringSlot.destroy_all
    assert_difference  'members(:f_mentor).reload.mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => st.strftime("%I:%M %P"), :end_time_of_day => en.strftime("%I:%M %P"), :repeats_every_option => "2",
        :date => st.strftime("%B %d, %Y"), :repeats_on_week => [st.wday.to_s]
      }}
      assert_equal 1, assigns(:mentoring_slots).count
      assert_equal "Not specified", assigns(:mentoring_slots)[0][:location]
      assert_equal 2, assigns(:mentoring_slots)[0][:repeats]
      assert_equal "week", assigns(:mentoring_slots)[0][:recurring_options][:every].to_s
    end
    m = MentoringSlot.last
    assert_time_string_equal(m.start_time, st)
    assert_time_string_equal(m.end_time, en)
    assert_equal m.repeats, MentoringSlot::Repeats::WEEKLY
    assert_equal st.wday.to_s, m.repeats_on_week
    members(:f_mentor).update_attributes!(will_set_availability_slots: false)
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => st.strftime("%I:%M %P"), :end_time_of_day => en.strftime("%I:%M %P"), :repeats_every_option => "2",
        :date => st.strftime("%B %d, %Y"), :repeats_on_week => [st.wday.to_s], :from_settings_page => "true"
      }}
      assert assigns(:from_settings_page)
      assert members(:f_mentor).reload.will_set_availability_slots
    end
  end

  def test_create_with_different_timezone
    st = "2999-02-20 23:00:00".to_datetime.in_time_zone("Asia/Kolkata")
    en = "2999-02-20 23:30:00".to_datetime.in_time_zone("Asia/Kolkata")

    Time.stubs(:zone).returns(ActiveSupport::TimeZone.new("Asia/Kolkata"))

    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => st.strftime("%I:%M %P"), :end_time_of_day => en.strftime("%I:%M %P"), :repeats_every_option => "2",
        :date => st.strftime("%B %d, %Y"), :repeats_on_week => [st.wday.to_s]
      }}
    end
    m = MentoringSlot.last
    assert_equal m.repeats, MentoringSlot::Repeats::WEEKLY
    # repeats_on_week is saved in UTC and retrieved in Time.zone
    assert_equal st.wday.to_s, m.repeats_on_week
  end

  def test_create_past_current_time
    st = 2.minutes.ago
    en = 60.minutes.since
    current_user_is :f_mentor
    assert_no_difference  'members(:f_mentor).mentoring_slots.size' do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => st.strftime("%I:%M %P"), :end_time_of_day => en.strftime("%I:%M %P"), :repeats_every_option => "2",
        :date => st.strftime("%B %d, %Y"), :repeats_on_week => [st.wday.to_s]
      }}
    end
  end

  def test_create_success_mst_time_zone
    members(:f_mentor).update_attribute(:time_zone, "America/Denver")
    st = 15.minutes.since
    en = 60.minutes.since
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => "10:00 am", :end_time_of_day => en.strftime("11:00 am"), :repeats_every_option => "2",
        :date => "August 15, 2025", :repeats_on_week => [st.wday.to_s]
      }}
    end
    m = MentoringSlot.last
    assert_equal "2025-08-15 10:00:00 -0600", m.start_time.to_s
    assert_equal "2025-08-15 11:00:00 -0600", m.end_time.to_s
    assert_equal m.repeats, MentoringSlot::Repeats::WEEKLY
    assert_equal st.wday.to_s, m.repeats_on_week
  end

  def test_create_failure
    st = 10.minutes.ago
    en = 15.minutes.ago
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 0 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => st.strftime("%I:%M %P"), :end_time_of_day => en.strftime("%I:%M %P"), :date => st.strftime("%B %d, %Y"),
          :repeats_every_option => "2", :repeats_on_week => ["5","6"]}
        }
    end
  end

  def test_update_success
    st = "2999-02-20 23:00:00".to_datetime.in_time_zone("Asia/Kolkata")
    en = st + 30.minutes
    Time.stubs(:zone).returns(ActiveSupport::TimeZone.new("Asia/Kolkata"))

    current_user_is :f_mentor
    put :update, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id, :mentoring_slot => {:start_time_of_day => st.strftime("%I:%M %P"),
        :end_time_of_day => en.strftime("%I:%M %P"), :date => st.strftime("%B %d, %Y"), :location => "arbit", :repeats_every_option => "2", :repeats_on_week => ["5","6"]}
      }

    assert_time_string_equal(mentoring_slots(:f_mentor).reload.start_time, st)
    assert_time_string_equal(mentoring_slots(:f_mentor).end_time, en)
    assert_equal mentoring_slots(:f_mentor).repeats, MentoringSlot::Repeats::WEEKLY
    assert_equal "5,6", mentoring_slots(:f_mentor).repeats_on_week
  end

  def test_update_failure
    st = mentoring_slots(:f_mentor).start_time
    en =mentoring_slots(:f_mentor).end_time
    current_user_is :f_mentor
    put :update, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id, :mentoring_slot => {:start_time_of_day => 10.minutes.ago.strftime("%I:%M %P"), :end_time_of_day => 16.minutes.ago.strftime("%I:%M %P"),
      :date => 10.minutes.ago.strftime("%B %d, %Y")
    }}
    assert_time_string_equal(mentoring_slots(:f_mentor).reload.start_time, st)
    assert_time_string_equal(mentoring_slots(:f_mentor).end_time, en)
  end

  def test_destroy
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', -1 do
      delete :destroy, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id}
      assert_false assigns(:from_settings_page)
    end
  end

  def test_destroy_slot_from_settings_page
    current_user_is :f_mentor
    slot = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_difference  'members(:f_mentor).mentoring_slots.size', -1 do
      delete :destroy, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id, :from_settings_page => true}
      assert assigns(:from_settings_page)
      assert_equal 1, assigns(:mentoring_slots).count
      assert_equal "Good unique name available at Indore", assigns(:mentoring_slots)[0][:title]
      assert_equal "Indore", assigns(:mentoring_slots)[0][:location]
    end
  end

  def test_create_permission_denied
    st = 10.minutes.ago
    en = 15.minutes.ago
    current_user_is :f_mentor_student
    assert_permission_denied do
      post :create, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time => st, :end_time => en, :repeats => MentoringSlot::Repeats::WEEKLY}}
    end
  end

  def test_update_permission_denied
    st = 10.minutes.ago
    en = 15.minutes.ago
    current_user_is :f_mentor_student
    assert_permission_denied do
      put :update, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id, :mentoring_slot => {:start_time => st.strftime('%Y-%m-%d %H:%M:%S'), :end_time => en.strftime('%Y-%m-%d %H:%M:%S')}}
    end
  end

  def test_destroy_permission_denied
    current_user_is :f_mentor_student
    assert_permission_denied do
      delete :destroy, params: { :member_id => members(:f_mentor).id,:id => mentoring_slots(:f_mentor).id}
    end
  end

  def test_index_non_self_view
    meetings(:f_mentor_mkr_student_daily_meeting).false_destroy!
    meetings(:upcoming_calendar_meeting).false_destroy!
    current_user_is :f_student
    st = mentoring_slots(:f_mentor).start_time.change(usec: 0)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), (st - 100.minutes), (st - 50.minutes), {duration: 50.minutes})
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    programs(:albers).enable_feature(FeatureName::CALENDAR_SYNC_V2)
    start_time = (mentoring_slots(:f_mentor).start_time - 2.days).to_i
    end_time = (mentoring_slots(:f_mentor).end_time + 2.days).to_i
    Member.expects(:get_busy_slots_for_members).with(Time.at(start_time), Time.at(end_time), members: [members(:f_mentor)], viewing_member: users(:f_student).member, program: users(:f_student).program).returns([])

    get :index, params: { member_id: members(:f_mentor), start: start_time, end: end_time}
    assert_equal assigns(:profile_member), members(:f_mentor)
    avail = assigns(:profile_member).get_mentoring_slots((mentoring_slots(:f_mentor).start_time - 2.days), (mentoring_slots(:f_mentor).end_time + 2.days), true)
    add_urls(avail)

    assert_mentoring_slots assigns(:availability), add_urls(assigns(:profile_member).get_availability_slots((mentoring_slots(:f_mentor).start_time - 2.days), (mentoring_slots(:f_mentor).end_time + 2.days), users(:f_student).program, true, nil, false, users(:f_student)))
    recurring_meetings = Meeting.recurrent_meetings([meetings(:f_mentor_mkr_student)], {get_merged_list: true})
    assert_mentoring_slots assigns(:meetings), members(:f_mentor).get_meeting_slots(recurring_meetings, [], members(:f_student))
  end

  def test_index_non_self_view_availability_respecting_max_capacity
    meetings(:f_mentor_mkr_student_daily_meeting).false_destroy!
    meetings(:upcoming_calendar_meeting).false_destroy!
    current_user_is :f_student
    time_now = Time.now.utc.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    st = mentoring_slots(:f_mentor).start_time.change(usec: 0)
    #after this meeting, max capacity  should be reached for mentor
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)

    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), (st - 100.minutes), (st - 20.minutes), {duration: 80.minutes})
    get :index, params: { :member_id => members(:f_mentor), :start => (mentoring_slots(:f_mentor).start_time - 2.days).to_i,
      :end => (mentoring_slots(:f_mentor).end_time + 2.days).to_i}
    assert_equal assigns(:profile_member), members(:f_mentor)

    assert_mentoring_slots assigns(:availability), []
    recurring_meetings = Meeting.recurrent_meetings([meetings(:f_mentor_mkr_student)], {get_merged_list: true})
    assert_mentoring_slots assigns(:meetings), members(:f_mentor).get_meeting_slots(recurring_meetings, [], members(:f_student))
  end

  def test_mentoring_slots_with_group_meeting_disabled
    meetings(:f_mentor_mkr_student_daily_meeting).false_destroy!
    meetings(:upcoming_calendar_meeting).false_destroy!
    current_user_is :f_student
    st = mentoring_slots(:f_mentor).start_time.change(usec: 0)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), (st - 100.minutes), (st - 50.minutes), {duration: 50.minutes})
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, false)

    get :index, params: { :member_id => members(:f_mentor), :start => (mentoring_slots(:f_mentor).start_time - 2.days).to_i,
      :end => (mentoring_slots(:f_mentor).end_time + 2.days).to_i}
    assert_equal assigns(:profile_member), members(:f_mentor)
    avail = assigns(:profile_member).get_mentoring_slots((mentoring_slots(:f_mentor).start_time - 2.days), (mentoring_slots(:f_mentor).end_time + 2.days), true, true)
    add_urls(avail)
    assert_mentoring_slots [], assigns(:meetings)

    #meetings should not include general availability meetings
    time = 2.days.from_now
    meeting = create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes)
    get :index, params: { :member_id => members(:f_mentor), :start => (meeting.start_time - 2.days).to_i,
      :end => (meeting.end_time + 2.days).to_i}
    assert_equal 0, assigns(:meetings).count
  end

  def test_index_non_self_view_not_attending
    current_user_is :f_student
    st = mentoring_slots(:f_mentor).start_time.utc.change(usec: 0)
    time_now = Time.now.utc.change(usec: 0)
    Time.stubs(:local).returns(time_now)
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), (st - 100.minutes), (st - 50.minutes), {duration: 50.minutes})
    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student).reload, attending: false)
    get :index, params: { :member_id => members(:f_mentor).reload, :start => (mentoring_slots(:f_mentor).start_time .utc- 2.days),
      :end => (mentoring_slots(:f_mentor).end_time.utc + 2.days)}
    assert_equal  [], assigns(:meetings)
  end

  def test_index_self_view
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    current_user_is :f_mentor
    member = members(:f_mentor)
    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    programs(:albers).enable_feature(FeatureName::CALENDAR_SYNC_V2)
    start_time = (mentoring_slots(:f_mentor).start_time - 2.days).to_i
    end_time = (mentoring_slots(:f_mentor).end_time + 2.days).to_i
    Member.expects(:get_busy_slots_for_members).with(Time.at(start_time), Time.at(end_time), members: [member], viewing_member: member, program: users(:f_student).program).returns([])

    get :index, params: { member_id: members(:f_mentor), start: start_time, end: end_time }
    assert_equal assigns(:profile_member), members(:f_mentor)
    avail = assigns(:profile_member).get_mentoring_slots((mentoring_slots(:f_mentor).start_time - 2.days), (mentoring_slots(:f_mentor).end_time + 2.days), true, nil, false, true,false,false, {check_for_expired_availability: true})
    add_urls(avail)
    assert_mentoring_slots assigns(:mentoring_slots), avail
    recurrent_meetings = Meeting.recurrent_meetings(members(:f_mentor).meetings, {get_merged_list: true, :start_time => (mentoring_slots(:f_mentor).start_time - 2.days),
      :end_time => (mentoring_slots(:f_mentor).end_time + 2.days), get_occurrences_between_time: true })
    assert_mentoring_slots assigns(:meetings), members(:f_mentor).get_meeting_slots(recurrent_meetings, members(:f_mentor).meetings.pluck(:id), members(:f_mentor))
  end

  def test_index_self_view_not_attending
    current_user_is :f_mentor
    meetings(:f_mentor_mkr_student).update_attributes(:owner_id => members(:mkr_student).id)
    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student).reload, attending: false)
    members(:f_mentor).mark_attending!(meetings(:upcoming_calendar_meeting).reload, attending: false)
    get :index, params: { :member_id => members(:f_mentor), :start => (mentoring_slots(:f_mentor).start_time - 2.days).to_i,
      :end => (mentoring_slots(:f_mentor).end_time + 2.days).to_i}
    assert_equal assigns(:profile_member), members(:f_mentor)
    assert_equal [], assigns(:meetings)
  end

  def test_create_with_repeats_end_date
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => "06:00 pm", :end_time_of_day => "08:00 pm", :repeats_every_option => MentoringSlot::Repeats::DAILY,
        :date => "February 26, 2025", :repeats_end_date_view => "February 27, 2025"
      }}
    end
    m = MentoringSlot.all.last
    assert_time_string_equal(m.start_time, "2025-02-26 18:00:00".to_time)
    assert_time_string_equal(m.end_time, "2025-02-26 20:00:00".to_time)
    assert_time_string_equal(m.repeats_end_date, "2025-02-28 00:00:00".to_time)
    assert_equal m.repeats, MentoringSlot::Repeats::DAILY
  end

  def test_create_with_repeat_monthly_and_repeats_end_date
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => "06:00 pm", :end_time_of_day => "08:00 pm", :repeats_every_option => MentoringSlot::Repeats::MONTHLY,
        :date => "February 26, 2025", :repeats_end_date_view => "February 27, 2025", :repeats_by_month_date => false
      }}
    end
    m = MentoringSlot.all.last
    assert_time_string_equal(m.start_time, "2025-02-26 18:00:00".to_time)
    assert_time_string_equal(m.end_time, "2025-02-26 20:00:00".to_time)
    assert_time_string_equal(m.repeats_end_date, "2025-02-28 00:00:00".to_time)
    assert_equal m.repeats, MentoringSlot::Repeats::MONTHLY
    assert_false m.repeats_by_month_date
  end

  def test_create_with_repeat_weekly_and_repeats_end_date
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => "06:00 pm", :end_time_of_day => "08:00 pm", :repeats_every_option => MentoringSlot::Repeats::MONTHLY,
        :date => "February 26, 2025", :repeats_end_date_view => "February 27, 2025", :repeats_on_week => ["4", "6"]
      }}
    end
    m = MentoringSlot.all.last
    assert_time_string_equal(m.start_time, "2025-02-26 18:00:00".to_time)
    assert_time_string_equal(m.end_time, "2025-02-26 20:00:00".to_time)
    assert_time_string_equal(m.repeats_end_date, "2025-02-28 00:00:00".to_time)
    assert_equal m.repeats, MentoringSlot::Repeats::MONTHLY
    assert_equal m.repeats_on_week, "4,6"
  end

  def test_create_with_no_repeats_and_end_date
    current_user_is :f_mentor
    assert_difference  'members(:f_mentor).mentoring_slots.size', 1 do
      post :create, xhr: true, params: { :member_id => members(:f_mentor).id, :mentoring_slot => {:start_time_of_day => "06:00 pm", :end_time_of_day => "08:00 pm", :repeats_every_option => MentoringSlot::Repeats::NONE,
        :date => "February 26, 2025", :repeats_end_date_view => "February 27, 2025"
      }}
    end
    m = MentoringSlot.all.last
    assert_time_string_equal(m.start_time, "2025-02-26 18:00:00".to_time)
    assert_time_string_equal(m.end_time, "2025-02-26 20:00:00".to_time)
    assert_nil m.repeats_end_date
    assert_equal MentoringSlot::Repeats::NONE, m.repeats
  end

  def test_index_feature_disabled
    programs(:org_primary).enable_feature(FeatureName::CALENDAR, false)
    current_user_is :f_mentor

    assert_raise Authorization::PermissionDenied do
      get :index, params: { :member_id => members(:f_admin).id}
    end
  end

  def test_index_permission_disabled
    current_user_is :f_mentor

    assert_raise Authorization::PermissionDenied do
      get :index, params: { :member_id => members(:f_admin).id}
    end
  end

  def test_edit_with_ist_time_zone
    members(:f_mentor).update_attribute(:time_zone, "Asia/Kolkata")
    current_user_is :f_mentor
    get :edit, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id,
      :mentoring_slot => {:start_time => "2011-08-15 10:00:00", :end_time => "2011-08-15 11:00:00"}}
    m = assigns(:mentoring_slot)
    assert_equal "2011-08-15 10:00:00 +0530", m.start_time.to_s
    assert_equal "2011-08-15 11:00:00 +0530", m.end_time.to_s
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert assigns(:can_mark_availability_slot)
  end

  def test_edit_with_mst_time_zone_with_dst
    members(:f_mentor).update_attribute(:time_zone, "America/Denver")
    current_user_is :f_mentor
    get :edit, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id,
      :mentoring_slot => {:start_time => "2011-08-15 10:00:00", :end_time => "2011-08-15 11:00:00"}}
    m = assigns(:mentoring_slot)
    assert_equal "2011-08-15 10:00:00 -0600", m.start_time.to_s
    assert_equal "2011-08-15 11:00:00 -0600", m.end_time.to_s
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert assigns(:can_mark_availability_slot)
  end

  def test_edit_with_mst_time_zone_without_dst
    members(:f_mentor).update_attribute(:time_zone, "America/Denver")
    current_user_is :f_mentor
    get :edit, xhr: true, params: { :member_id => members(:f_mentor).id, :id => mentoring_slots(:f_mentor).id,
      :mentoring_slot => {:start_time => "2011-02-26 10:00:00", :end_time => "2011-02-26 11:00:00"}}
    m = assigns(:mentoring_slot)
    assert_equal "2011-02-26 10:00:00 -0700", m.start_time.to_s
    assert_equal "2011-02-26 11:00:00 -0700", m.end_time.to_s
    assert_equal 30, assigns(:allowed_individual_slot_duration)
    assert assigns(:can_mark_availability_slot)
  end

  def test_new_without_mentoring_slot_time
    current_user_is :f_mentor
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    programs(:albers).calendar_setting.update_attribute(:allow_create_meeting_for_mentor, true)
    men = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_equal men, members(:f_mentor).mentoring_slots.last
    current_time = "2025-02-26 18:00:00".to_time.utc
    Time.stubs(:now).returns(current_time)
    st = (current_time + 1.day).round_to_next
    en = st + 30.minutes
    get :new, params: { :member_id => members(:f_mentor).id}
    assert_response :success
    assert_equal ["Bhopal", "Indore", "Chennai"], assigns(:mentoring_slot_locations)

    assert_time_string_equal st.utc, assigns(:mentoring_slot).start_time.utc
    assert_time_string_equal (st + 30.minutes).utc, assigns(:mentoring_slot).end_time.utc
    assert_equal 30, assigns(:allowed_individual_slot_duration)

    assert_equal st.to_i, assigns(:new_meeting).start_time.to_i
    assert_equal (st + 30.minutes).to_i, assigns(:new_meeting).end_time.to_i
    assert assigns(:can_current_user_create_meeting) #current_user is mentor, calendar feature is enabled and mentor can create meeting.
    assert assigns(:can_mark_availability_slot)
  end

end