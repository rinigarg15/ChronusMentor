require_relative './../test_helper.rb'

class RecentActivityTest < ActiveSupport::TestCase
  def test_action_type_and_target_cannot_be_null
    assert_multiple_errors([{:field => :target}, {:field => :action_type}]) do
      RecentActivity.create!
    end
  end

  def test_target_is_required
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :target do
      RecentActivity.create!(:action_type => 12, :target => 24)
    end
  end

  def test_action_type_is_required
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :action_type do
      RecentActivity.create!(:action_type => 1000, :target => 24)
    end
  end

  def test_should_create_recent_activity_and_check_programs_association
    assert_difference 'ProgramActivity.count', 2 do
      assert_difference("RecentActivity.count") do
        @activity = RecentActivity.create!(
          :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
          :target => RecentActivityConstants::Target::MENTORS,
          :programs => [programs(:albers), programs(:nwen)]
        )
      end
    end

    assert_equal [programs(:albers), programs(:nwen)], @activity.programs

    assert_difference 'ProgramActivity.count', -2 do
      assert_difference "RecentActivity.count", -1 do
        @activity.destroy
      end
    end
  end

  def test_non_user_recent_activity_should_not_have_for_id
    e = assert_raise(ActiveRecord::RecordInvalid) {
      r = RecentActivity.create!(
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :for_id => users(:f_admin).id
      )
    }

    assert_match(/for_id and target incompatible/, e.message)
  end

  def test_user_directed_recent_activity_should_not_have_non_user_target_type
    e = assert_raise(ActiveRecord::RecordInvalid) {
      r = RecentActivity.create!(
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::USER
      )
    }

    assert_match(/for_id and target incompatible/, e.message)
  end

  def test_for_of_type_should_fetch_only_entries_of_right_type
    RecentActivity.destroy_all
    g = groups(:mygroup)
    g.set_member_status(g.membership_of(users(:f_mentor)), Connection::Membership::Status::INACTIVE)
    g.set_member_status(g.membership_of(users(:mkr_student)), Connection::Membership::Status::INACTIVE)

    act1 = RecentActivity.create!(
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :programs => [programs(:albers)]
      )
      
    act2 = RecentActivity.create!(
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :programs => [programs(:albers)]
      )

    act3 = RecentActivity.create!(
          :ref_obj => g,
          :action_type => RecentActivityConstants::Type::VISIT_MENTORING_AREA,
          :programs => [programs(:albers)],
          :member => members(:f_mentor),
          :target => RecentActivityConstants::Target::NONE)

    act4 = RecentActivity.create!(
          :ref_obj => g,
          :action_type => RecentActivityConstants::Type::GROUP_REACTIVATION,
          :programs => [programs(:albers)],
          :member => members(:f_mentor),
          :target => RecentActivityConstants::Target::ALL)
        
    
    acts1 = RecentActivity.of_type(RecentActivityConstants::Type::GROUP_REACTIVATION)
    
    assert_equal([act4], acts1)
    assert_false RecentActivity.not_of_types([RecentActivityConstants::Type::GROUP_REACTIVATION]).include?(act4)
    
    acts2 = RecentActivity.of_type(RecentActivityConstants::Type::ANNOUNCEMENT_CREATION)
    assert_equal([act1, act2], acts2)
    assert (RecentActivity.not_of_types([RecentActivityConstants::Type::ANNOUNCEMENT_CREATION]) & [act1, act2]).empty?

    acts3 = RecentActivity.of_type(RecentActivityConstants::Type::VISIT_MENTORING_AREA)
    assert_equal([act3], acts3)
    assert_false RecentActivity.not_of_types([RecentActivityConstants::Type::VISIT_MENTORING_AREA]).include?(act3)
  end


  def test_for_admin_scope_should_fetch_only_entries_for_admin
    recent_activity_creation_triggers

    # should fetch the membership request,user create, mentor requests and announcement
    acts = RecentActivity.for_admin(users(:f_admin))
    assert_equal(11, acts.size)
  end

  def test_for_mentor_scope_should_fetch_only_entries_for_mentor
    recent_activity_creation_triggers

    # should fetch the membership,mentor requests and announcement
    acts = RecentActivity.for_mentor(users(:f_mentor))
    assert_equal(8, acts.size)
  end

  def test_for_mentor_and_mentee_scope_should_fetch_all_mentor_mentee_entries
    recent_activity_creation_triggers

    # should fetch the membership request and announcement
    acts = RecentActivity.for_mentor_and_student(users(:f_mentor_student))
    # For mentor_join_program, and all 3 announcements
    assert_equal(3, acts.size)
  end

  def test_for_all_scope_should_fetch_ra_trageted_for_all
    recent_activity_creation_triggers

    # should fetch the new users and announcements
    acts = RecentActivity.for_all(users(:f_admin))
    # For mentor_join_program, and all 3 announcements
    assert_equal(3, acts.size)
  end

  def test_for_other_non_administrative_roles_scope_should_fetch_all_other_non_administrative_roles_entries
    recent_activity_creation_triggers

    # should fetch the new user and announcement
    acts = RecentActivity.for_other_non_administrative_roles(users(:f_user))
    assert_equal(1, acts.size)
    create_announcement(:title => "Hello user", :program => programs(:albers), :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    acts = RecentActivity.for_other_non_administrative_roles(users(:f_user))
    assert_equal(2, acts.size)
  end

  def test_for_student_scope_should_fetch_only_entries_
    # Wipe all activities and create only an annoucement create, request create
    # and update.
    RecentActivity.destroy_all
    create_announcement(:program => programs(:albers),
      :admin => users(:f_admin), :title => "Hello",
      :recipient_role_names => [RoleConstants::STUDENT_NAME])

    mentor_request = create_mentor_request(:student => users(:f_student))
    mentor_request.mark_accepted!

    mentor_request1 = create_mentor_request(:student => users(:f_student))
    mentor_request1.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::WITHDRAWN)

    acts = RecentActivity.for_student(users(:f_student))
    assert_equal(5, acts.size)
  end

  def test_create_connection_activity
    assert_difference("Connection::Activity.count") do
      assert_difference("RecentActivity.count") do
        @act_1 = RecentActivity.create!(
          :ref_obj => messages(:mygroup_mentor_1),
          :action_type => RecentActivityConstants::Type::SCRAP_CREATION,
          :programs => [messages(:mygroup_mentor_1).ref_obj.program],
          :member => messages(:mygroup_mentor_1).sender,
          :target => RecentActivityConstants::Target::ALL)
      end
    end
    conn_act = Connection::Activity.last
    assert_equal @act_1, conn_act.recent_activity
    assert_equal messages(:mygroup_mentor_1).ref_obj, conn_act.group
    
    assert_difference("Connection::Activity.count") do
      assert_difference("RecentActivity.count") do
        @act_2 = RecentActivity.create!(
          :ref_obj => groups(:mygroup),
          :action_type => RecentActivityConstants::Type::VISIT_MENTORING_AREA,
          :programs => [groups(:mygroup).program],
          :member => members(:f_mentor),
          :target => RecentActivityConstants::Target::NONE)
      end
    end

    conn_act = Connection::Activity.last
    assert_equal @act_2, conn_act.recent_activity
    assert_equal groups(:mygroup), conn_act.group

    assert_difference("Connection::Activity.count") do
      assert_difference("RecentActivity.count") do
        @act_3 = RecentActivity.create!(
          :ref_obj => groups(:mygroup),
          :action_type => RecentActivityConstants::Type::GROUP_REACTIVATION,
          :programs => [groups(:mygroup).program],
          :member => members(:f_mentor),
          :target => RecentActivityConstants::Target::ALL)
      end
    end

    conn_act = Connection::Activity.last
    assert_equal @act_3, conn_act.recent_activity
    assert_equal groups(:mygroup), conn_act.group

    assert_difference("Connection::Activity.count") do
      assert_difference("RecentActivity.count") do
        @act_4 = RecentActivity.create!(
          :ref_obj => groups(:mygroup),
          :action_type => RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
          :programs => [groups(:mygroup).program],
          :member => members(:f_mentor),
          :target => RecentActivityConstants::Target::ALL)
      end
    end

    conn_act = Connection::Activity.last
    assert_equal @act_4, conn_act.recent_activity
    assert_equal groups(:mygroup), conn_act.group

    assert_difference("Connection::Activity.count") do
      assert_difference("RecentActivity.count") do
        @act_5 = RecentActivity.create!(
          :ref_obj => groups(:mygroup),
          :action_type => RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY,
          :programs => [groups(:mygroup).program],
          :member => members(:f_mentor),
          :target => RecentActivityConstants::Target::ALL)
      end
    end

    conn_act = Connection::Activity.last
    assert_equal @act_5, conn_act.recent_activity
    assert_equal groups(:mygroup), conn_act.group
  end

  def test_should_create_recent_activity_targeted_at_none
    art = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::ALL,
      :programs => [programs(:albers)]
    )

    assert RecentActivity.for_display.include?(art)

    art_1 = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::NONE,
      :programs => [programs(:albers)]
    )
    assert_false RecentActivity.for_display.include?(art_1)
  end


  def test_get_user
    @activity = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS,
      :member => members(:f_mentor)
    )

    @activity.programs << programs(:albers)

    albers_activity = ProgramActivity.last
    assert_equal @activity.get_user(programs(:albers)), albers_activity.user
    assert_equal @activity.get_user(programs(:albers).id), albers_activity.user

    @activity.programs << programs(:nwen)

    nwen_activity = ProgramActivity.last
    assert_equal @activity.get_user(programs(:nwen)), nwen_activity.user
  end

  def test_by_member_scope
    assert_equal [], RecentActivity.by_member(members(:f_mentor))

    activity_1 = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS,
      :programs => [programs(:albers), programs(:nwen)],
      :member => members(:f_mentor)
    )

    assert_equal [activity_1], RecentActivity.by_member(members(:f_mentor))

    activity_2 = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS,
      :programs => [programs(:albers)],
      :member => members(:f_mentor)
    )

    activity_3 = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS,
      :programs => [programs(:albers)],
      :member => members(:f_student)
    )

    assert_equal [activity_1, activity_2], RecentActivity.by_member(members(:f_mentor))
    assert_equal [activity_3], RecentActivity.by_member(members(:f_student))
  end

  def test_for_multiple_programs
    activity = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      :target => RecentActivityConstants::Target::MENTORS
    )

    assert_false activity.for_multiple_programs?
    activity.programs << programs(:ceg)

    assert_false activity.reload.for_multiple_programs?
    activity.programs << programs(:nwen)

    assert activity.reload.for_multiple_programs?
  end

  def test_with_offset_and_length
    RecentActivity.destroy_all

    activities = []

    0.upto(4) do |i|
      activities << RecentActivity.create!(
        :programs => [programs(:albers)],
        :action_type => RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        :target => RecentActivityConstants::Target::MENTORS,
        :created_at => i.days.ago,
        :ref_obj => announcements(:assemble))
    end

    assert_equal activities,                      RecentActivity.all
    assert_equal [activities[0], activities[1]],  RecentActivity.with_upper_offset(activities[4].id).with_length(2)
    assert_equal [activities[0]],                 RecentActivity.with_upper_offset(activities[1].id).with_length(3)
    assert_equal [],                              RecentActivity.with_upper_offset(activities[0].id).with_length(2)
    assert_equal [activities[0]],                 RecentActivity.with_upper_offset(activities[2].id).with_length(1)
    assert_equal [],                              RecentActivity.with_upper_offset(activities[3].id).with_length(0)
    assert_equal [activities[0], activities[1]],  RecentActivity.with_length(2)
    assert_equal activities,                      RecentActivity.with_length(10)
    assert_equal [],                              RecentActivity.with_upper_offset(activities[0].id - 5).with_length(10)
  end

  def test_create_connection_activities_for_meeting_create
    chronus_s3_utils_stub
    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since)
      end
    end

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_nil ra.for

    #meeting without a group
    assert_no_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since, :force_non_group_meeting => true)
      end
    end

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Target::USER, ra.target
    assert_equal members(:mkr_student), ra.for
  end

  def test_create_connection_activities_for_meeting_update
    chronus_s3_utils_stub
    meeting = create_meeting
    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        meeting.update_attributes(:description => "Sample Meeting")
      end
    end

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_nil ra.for

    #meeting without a group
    meeting = create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since, :force_non_group_meeting => true)
    assert_no_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        meeting.update_attributes(:description => "Sample Meeting")
      end
    end

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Target::USER, ra.target
    assert_equal members(:mkr_student), ra.for
  end

  def test_create_connection_activities_for_meeting_decline
    chronus_s3_utils_stub
    meeting = create_meeting(:start_time => 40.minutes.from_now, :end_time => 60.minutes.from_now)
    member_meeting = meeting.member_meetings.where(:member_id => users(:mkr_student).member).first

    assert_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        member_meeting.update_attributes(:attending => false)
      end
    end

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Target::USER, ra.target
    assert_equal members(:f_mentor), ra.for

    #meeting without a group
    meeting = create_meeting(:start_time => 40.minutes.since, :end_time => 60.minutes.since, :force_non_group_meeting => true)
    member_meeting = meeting.member_meetings.where(:member_id => users(:mkr_student).member).first
    assert_no_difference "Connection::Activity.count" do
      assert_difference "RecentActivity.count" do
        member_meeting.update_attributes!(:attending => false)
      end
    end

    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Target::USER, ra.target
    assert_equal members(:f_mentor), ra.for
  end

  private

  def recent_activity_creation_triggers
    RecentActivity.destroy_all
    
    # membership create
    create_membership_request

    # announcement create
    create_announcement(:program => programs(:albers),
      :admin => users(:f_admin), :title => "Hello", :recipient_role_names => programs(:albers).roles_without_admin_role.collect(&:name))
    create_announcement(:program => programs(:albers),
      :admin => users(:f_admin), :title => "Hello", :recipient_role_names => [RoleConstants::STUDENT_NAME])
    create_announcement(:program => programs(:albers),
      :admin => users(:f_admin), :title => "Hello", :recipient_role_names => [RoleConstants::MENTOR_NAME])

    # user create
    create_user(:name => "mentor_pal", :role_names => [RoleConstants::MENTOR_NAME])
    create_user(:name => "mentee_pal", :role_names => [RoleConstants::STUDENT_NAME])

    # mentor request
    request1 = create_mentor_request; request1.mark_accepted!
    request2 = create_mentor_request
    request2.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::REJECTED)
    request3 = create_mentor_request
    request3.update_attributes(:response_text => "Sorry", :status => AbstractRequest::Status::WITHDRAWN)
    # TODO: one-on-one notification - scrap, task etc - to be added
  end
end
