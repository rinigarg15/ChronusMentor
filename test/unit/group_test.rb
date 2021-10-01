require_relative './../test_helper.rb'

class GroupTest < ActiveSupport::TestCase
  def test_has_many_mentors
    allow_one_to_many_mentoring_for_program(programs(:albers))

    assert_difference 'Group.count' do
      updated_at = users(:mentor_3).updated_at.to_i
      @group = create_group(
        :program => programs(:albers),
        :mentors => [users(:mentor_3), users(:mentor_4)],
        :students => [users(:student_4), users(:student_5)],
        :notes => "This is a test group"
      )
      assert_not_equal updated_at, User.find(users(:mentor_3).id).updated_at.to_i
    end
    assert_equal [users(:mentor_3), users(:mentor_4)], @group.mentors
    assert_equal [users(:student_4), users(:student_5)], @group.students
    assert_equal "This is a test group", @group.notes
  end

  def test_closure_survey
    group = groups(:mygroup)
    survey = surveys(:two)

    milestone = create_mentoring_model_milestone
    task1 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, milestone_id: milestone.id)
    assert group.closure_survey?(task1)

    task2 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, milestone_id: milestone.id)
    assert_false group.closure_survey?(task1)
    assert group.closure_survey?(task2)

    goal = create_mentoring_model_goal
    task3 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, goal_id: goal.id)
    assert_false group.closure_survey?(task3)

    milestone2 = create_mentoring_model_milestone
    assert_false group.closure_survey?(task1)
  end

  def test_badge_count_for_group
    group1 = create_group(students: users(:rahim), mentor: users(:f_mentor), program: programs(:albers))
    Program.any_instance.stubs(:show_meetings?).returns(true)
    Program.any_instance.stubs(:is_meetings_enabled_for_calendar_or_groups?).returns(true)
    Group.any_instance.stubs(:scraps_enabled?).returns(true)
    Program.any_instance.stubs(:mentoring_connection_meeting_enabled?).returns(true)
    mentor_member = members(:f_mentor)
    mentee_member = members(:rahim)
    connection_membership_ids = mentor_member.user_in_program(programs(:albers)).connection_memberships.pluck(:id)
    tasks = group1.mentoring_model_tasks.where(connection_membership_id: connection_membership_ids)
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 0, badge_hash[:unread_message_count]
    assert_equal 0, badge_hash[:upcoming_meeting_count]
    assert_equal 0, badge_hash[:tasks_count]
    create_scrap(sender: members(:rahim), group: group1)
    group1.reload
    mentor_member.reload
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    m = create_meeting(start_time: 20.minutes.from_now, end_time: 50.minutes.from_now, :group_id => group1.id, :members => [mentor_member, mentee_member], :owner_id => mentee_member.id)
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    assert_equal 1, badge_hash[:upcoming_meeting_count]
    update_recurring_meeting_start_end_date(m, 1.weeks.ago.beginning_of_day, 1.weeks.ago.beginning_of_day + 30.minutes)
    m.reload
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    assert_equal 0, badge_hash[:upcoming_meeting_count]
    update_recurring_meeting_start_end_date(m, 60.days.from_now.beginning_of_day - 1.day, 60.days.from_now.beginning_of_day - 1.day + 30.minutes)
    m.reload
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    assert_equal 1, badge_hash[:upcoming_meeting_count]
    mentor_member.mark_attending!(m, attending: MemberMeeting::ATTENDING::YES)
    m.reload
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    assert_equal 0, badge_hash[:upcoming_meeting_count]
    t1 = create_mentoring_model_task(due_date: Time.now + 6.days, required: true, group: group1)
    tasks = group1.mentoring_model_tasks.where(connection_membership_id: connection_membership_ids)
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    assert_equal 0, badge_hash[:upcoming_meeting_count]
    assert_equal 1, badge_hash[:tasks_count]
    t1.update_attributes(due_date: Time.now + 17.days)
    t1.reload
    badge_hash = group1.badge_counts(users(:f_mentor))
    assert_equal 1, badge_hash[:unread_message_count]
    assert_equal 0, badge_hash[:upcoming_meeting_count]
    assert_equal 0, badge_hash[:tasks_count]
    assert_equal 0, badge_hash[:unread_posts_count]

    user = users(:f_mentor)
    group1.stubs(:forum_enabled?).returns(true)
    group1.expects(:get_cummulative_unviewed_posts_count).with(user).returns(5)
    badge_hash = group1.badge_counts(user)
    assert_equal 5, badge_hash[:unread_posts_count]
  end

  def test_get_cummulative_unviewed_posts_count
    group = groups(:mygroup)
    mentor = group.mentors.first
    student = group.students.first
    assert_equal 0, group.get_cummulative_unviewed_posts_count(mentor)
    assert_equal 0, group.get_cummulative_unviewed_posts_count(student)
    group.mentoring_model = mentoring_models(:mentoring_models_1)
    group.mentoring_model.allow_forum = true
    group.save
    group.create_group_forum
    assert_equal 0, group.get_cummulative_unviewed_posts_count(users(:f_admin))
    topic1 = create_topic(forum: group.forum, user: mentor)
    post1 = create_post(topic: topic1, user: mentor)
    User.any_instance.expects(:get_cummulative_unviewed_posts).returns([post1])
    assert_equal 1, group.get_cummulative_unviewed_posts_count(mentor)
  end

  def test_time_for_feedback_form
    group = groups(:mygroup)
    student = group.students.first
    group_1 = create_group(:student => student, :mentors => [users(:mentor_2)])

    feedback_survey = programs(:albers).feedback_survey
    effectiveness_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::EFFECTIVENESS)
    connectivity_question = feedback_survey.survey_questions.find_by(question_mode: CommonQuestion::Mode::CONNECTIVITY)

    programs(:albers).update_attribute :inactivity_tracking_period, 30.days
    group.update_attribute :created_at, 35.days.ago
    group.update_attribute :published_at, 35.days.ago

    # No feedback yet.
    assert group.time_for_feedback_from?(student)

    # New group. Ask only for 30 days.
    assert_false group_1.time_for_feedback_from?(student)

    group_1.update_attribute :created_at, 40.days.ago
    group_1.update_attribute :published_at, 40.days.ago

    # Student provides feedback for group
    resp = Survey::SurveyResponse.new(feedback_survey, {user_id: student.id, group_id: group.id})
    resp.save_answers({effectiveness_question.id => "Poor", connectivity_question.id => "Phone"})

    assert_false group.time_for_feedback_from?(student)
    assert group_1.time_for_feedback_from?(student)

    SurveyAnswer.where(user_id: student.id, group_id: group.id, response_id: resp.id).update_all(created_at: 31.days.ago)

    # Student provides feedback for group_1
    resp_1 = Survey::SurveyResponse.new(feedback_survey, {user_id: student.id, group_id: group_1.id})
    resp_1.save_answers({effectiveness_question.id => "Good", connectivity_question.id => "Phone"})

    assert group.time_for_feedback_from?(student)
    assert_false group_1.time_for_feedback_from?(student)

    SurveyAnswer.where(user_id: student.id, group_id: group.id, response_id: resp.id).update_all(created_at: 29.days.ago)

    assert_false group.time_for_feedback_from?(student)
    assert_false group_1.time_for_feedback_from?(student)
  end

  def test_create_group_success
    make_member_of(:moderated_program, :f_student)
    assert_difference 'Group.count' do
      assert_no_difference 'RecentActivity.count' do
        assert_emails 2 do
          create_group(:students => [users(:f_student)], :mentors => [users(:moderated_mentor)], :program => programs(:moderated_program))
        end
      end
    end

    group = Group.last
    assert_equal [users(:f_student)], group.students
    assert_equal [users(:moderated_mentor)], group.mentors
    assert_equal programs(:moderated_program), group.program
    assert_equal Group::Status::ACTIVE, group.status
    check_group_state_change_unit(group, GroupStateChange.last, nil)
    # By default group is not global
    assert_false group.global?
  end

  def test_create_group_and_membership_state_changes
    group = groups(:mygroup)
    group_from_status = group.status
    memberships_users_info = {}
    group.memberships.each do |membership|
      memberships_users_info[membership.id] = {
        from_state: membership.user.state,
        to_state: membership.user.state,
        role_ids: membership.user.role_ids,
        role_ids_in_active_groups: membership.user.role_ids_in_active_groups
      }
    end
    assert_difference 'GroupStateChange.count', 1 do
      assert_difference 'ConnectionMembershipStateChange.count', 2 do
        group_info = {from_state: group_from_status, to_state: Group::Status::CLOSED}
        Group.create_group_and_membership_state_changes(group.id, Time.now, group_info, memberships_users_info)
      end
    end
    membership_state_change = group.connection_membership_state_changes.last
    info_hash = membership_state_change.info_hash
    assert_equal group_from_status, info_hash[:group][:from_state]
    assert_equal Group::Status::CLOSED, info_hash[:group][:to_state]
    assert_equal Connection::Membership::Status::ACTIVE, info_hash[:connection_membership][:from_state]
    assert_equal Connection::Membership::Status::ACTIVE, info_hash[:connection_membership][:to_state]
    assert_equal membership_state_change.user.state, info_hash[:user][:from_state]
    assert_equal membership_state_change.user.state, info_hash[:user][:to_state]

    assert_no_difference 'ConnectionMembershipStateChange.count' do
      group_info = {from_state: nil, to_state: Group::Status::CLOSED}
      Group.create_group_and_membership_state_changes(group.id, Time.now, group_info, memberships_users_info)
    end
  end

  def test_create_drafted_group_success_no_mail
    make_member_of(:moderated_program, :f_student)
    assert_difference 'Group.count' do
      assert_no_difference 'RecentActivity.count' do
        assert_emails 0 do
          create_group(:students => [users(:f_student)], :mentors => [users(:moderated_mentor)], :program => programs(:moderated_program), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
        end
      end
    end

    group = Group.last
    assert_equal [users(:f_student)], group.students
    assert_equal [users(:moderated_mentor)], group.mentors
    assert_equal programs(:moderated_program), group.program
    assert_equal Group::Status::DRAFTED, group.status
    # By default group is not global
    assert_false group.global?
  end

  def test_create_group_success_with_ra
    assert_difference 'Group.count' do
      assert_emails 2 do
        assert_difference 'RecentActivity.count' do
          create_group(
            :students => [users(:f_student)], :mentors => [users(:f_mentor)],
            :program => programs(:albers), :actor => users(:f_admin), :message => "Hi")
        end
      end
    end

    group = Group.last
    ra = RecentActivity.last
    assert_equal [users(:f_student)], group.students
    assert_equal [users(:f_mentor)], group.mentors
    assert_equal programs(:albers), group.program
    assert_equal Group::Status::ACTIVE, group.status

    assert_equal users(:f_admin), ra.get_user(programs(:albers))
    assert_equal group, ra.ref_obj
    assert_equal "Hi", ra.message
    assert_equal RecentActivityConstants::Target::NONE, ra.target
    assert_equal RecentActivityConstants::Type::GROUP_CREATION, ra.action_type
  end

  def test_es_reindex
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Member, [members(:mkr_student).id, members(:f_mentor).id])
    Group.es_reindex(groups(:mygroup), {:reindex_member => true})
  end

  def test_reindex_member
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(Member, [members(:mkr_student).id, members(:f_mentor).id])
    Group.reindex_member([groups(:mygroup).id])
  end

  def test_group_creation_should_send_email_to_all_participants
    allow_one_to_many_mentoring_for_program(programs(:moderated_program))
    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :rahim)
    make_member_of(:moderated_program, :mkr_student)

    make_member_of(:moderated_program, :mentor_3)
    users(:mentor_3).update_attributes(:max_connections_limit => 10)

    ActionMailer::Base.deliveries.clear

    assert_difference 'Group.count' do
      assert_emails 4 do
        create_group(
          :students => [users(:f_student), users(:rahim), users(:mkr_student)],
          :mentors => [users(:mentor_3)],
          :program => programs(:moderated_program))
      end
    end

    mails = ActionMailer::Base.deliveries
    assert_equal 4, mails.size
    assert_equal_unordered [users(:mentor_3).email, users(:f_student).email, users(:rahim).email, users(:mkr_student).email], mails.collect(&:to).flatten
  end

  def test_notification_on_tightly_managed_group_creation
    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :ram)
    make_member_of(:moderated_program, :f_admin)

    assert_difference 'Group.count' do
      assert_emails 2 do
        create_group(
          :students => [users(:f_student)],
          :mentors => [users(:ram)],
          :program => programs(:moderated_program))
      end
    end

    group = Group.last
    assert_equal [users(:f_student)], group.students
    assert_equal [users(:ram)], group.mentors
    assert_equal programs(:moderated_program), group.program
  end

  def test_student_is_required
    mentee_term = programs(:albers).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME)
    mentee_term.update_attribute(:pluralized_term, "Bikes")
    assert_no_difference 'Group.count' do
      assert_raise ActiveRecord::RecordInvalid, "Bikes can't be blank" do
        Group.create!(
          :mentors => [users(:f_mentor)],
          :program => programs(:albers))
      end
    end
  end

  def test_mentor_is_required
    mentor_term = programs(:albers).term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::MENTOR_NAME)
    mentor_term.update_attribute(:pluralized_term, "Cars")
    assert_no_difference 'Group.count' do
      assert_raise ActiveRecord::RecordInvalid, "Cars can't be blank" do
        Group.create!(
          :students => [users(:f_student)],
          :program => programs(:albers))
      end
    end
  end

  def test_expiry_time_is_required
    program = programs(:albers)
    group = program.groups.create!(mentors: [users(:f_mentor)], students: [users(:f_student)])
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :expiry_time, "can't be blank" do
      group.update_attributes!(expiry_time: nil)
    end
  end

  def test_expiry_time_not_required_for_drafted_group_creation
    assert_difference 'Group.count' do
      Group.create!(
        :mentors => [users(:f_mentor)],
        :students => [users(:f_student)], :program => programs(:albers), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    end
  end

  def test_mentor_connection_limit_got_crossed
    Group.destroy_all
    p = programs(:moderated_program)
    allow_one_to_many_mentoring_for_program(p)
    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :f_mentor_student)
    make_member_of(:moderated_program, :rahim)

    assert_equal 2, users(:moderated_mentor).max_connections_limit
    g = Group.new(:students => [users(:f_student), users(:f_mentor_student), users(:rahim)], :mentors => [users(:moderated_mentor)], :program => p)
    assert_false g.valid?
  end

  def test_program_is_required
    program = programs(:albers)
    group = Group.new(
      :students => [users(:f_student)],
      :mentors => [users(:f_mentor)]
    )
    group.valid? rescue true
    assert_equal ["can't be blank"], group.errors[:program]
  end

  def test_has_member
    group = create_group(:students => [users(:f_student)], :mentors => [users(:f_mentor)], :program => programs(:albers))

    assert group.has_member?(users(:f_student))
    assert group.has_member?(users(:f_mentor))
    assert !group.has_member?(users(:ram))
    assert !group.has_member?(users(:f_admin))
  end

  def test_has_one_forum
    group = groups(:mygroup)
    assert_nil group.forum

    forum = create_forum(name: "Group Forum", description: "Discussion Board", group_id: group.id)
    assert_equal forum, group.reload.forum

    e = assert_raise(ActiveRecord::RecordInvalid) do
      create_forum(name: "Group Forum 2", description: "Discussion Board", group_id: group.id)
    end
    assert_match("Group has already been taken", e.message)
  end

  def test_has_many_topics
    group = groups(:group_pbe)
    forum = group.forum
    user = group.mentors.first

    assert_empty group.topics
    topic1 = create_topic(forum: group.forum, user: user)
    topic2 = create_topic(forum: group.forum, user: user)

    assert_equal_unordered [topic1, topic2], group.topics.to_a
  end

  def test_has_many_posts
    group = groups(:group_pbe)
    user = group.mentors.first
    forum = group.forum
    topic1 = create_topic(forum: group.forum, user: user)

    assert_empty group.posts
    post1 = create_post(topic: topic1, user: user)
    post2 = create_post(topic: topic1, user: user)

    assert_equal_unordered [post1, post2], group.posts.to_a
  end

  def test_has_many_scraps
    student = users(:f_student)
    mentor = users(:f_mentor)

    group = create_group(:students => [student], :mentors => [mentor], :program => programs(:albers))

    scraps = []
    time_traveller(2.days.ago) do
      scraps << Scrap.create!(:ref_obj => group, :subject => "hello", :content => "Scrap Message Content", :sender => members(:f_student), :program => programs(:albers))
    end

    time_traveller(1.days.ago) do
      scraps << Scrap.create!(:ref_obj => group, :subject => "hai", :content => "Scrap Message Content", :sender => members(:f_mentor), :program => programs(:albers))
    end

    assert_equal_unordered scraps, group.scraps
  end

  def test_nullify_scrap_group_ids_on_destroy
    group = groups(:mygroup)
    assert_equal 6, Scrap.where(ref_obj_id: group.id, ref_obj_type: Group.to_s).size
    assert_no_difference "Scrap.count" do
      group.destroy
    end
    assert_blank Scrap.where(ref_obj_id: group.id, ref_obj_type: Group.to_s)
  end

  def test_has_many_memberships
    assert_equal [
        fetch_connection_membership(:student, groups(:mygroup)),
        fetch_connection_membership(:mentor, groups(:mygroup))],
      groups(:mygroup).memberships.reload
  end

  def test_has_many_mentoring_model_goals
    group = groups(:mygroup)
    goal_1 = group.mentoring_model_goals.create!(title: "Hello1", description: "Hello1Desc")
    goal_2 = group.mentoring_model_goals.create!(title: "Hello1", description: "Hello1Desc")
    goal_3 = group.mentoring_model_goals.create!(title: "Hello1", description: "Hello1Desc")
    assert_equal [goal_1, goal_2, goal_3], group.mentoring_model_goals
  end

  def test_destroying_group_destroy_mentoring_model_goals
    group = groups(:mygroup)
    goal_1 = group.mentoring_model_goals.create!(title: "Hello1", description: "Hello1Desc")
    goal_2 = group.mentoring_model_goals.create!(title: "Hello1", description: "Hello1Desc")
    goal_3 = group.mentoring_model_goals.create!(title: "Hello1", description: "Hello1Desc")
    assert_equal [goal_1, goal_2, goal_3], group.mentoring_model_goals
    assert_difference 'MentoringModel::Goal.count', -3 do
      group.destroy
    end
  end

  def test_destroying_group_destroy_connection_membership_state_change
    group = groups(:mygroup)
    group_id = group.id
    assert_not_equal [], ConnectionMembershipStateChange.where(group_id: group_id)
    group.destroy
    assert_equal [], ConnectionMembershipStateChange.where(group_id: group_id)
  end

  def test_has_many_project_requests
    group = groups(:group_pbe)
    req1 = group.project_requests.create!(message: "Hi", sender: users(:pbe_student_1), program: programs(:pbe))
    req2 = group.project_requests.create!(message: "Hi", sender: users(:pbe_student_2), program: programs(:pbe))
    req3 = group.project_requests.create!(message: "Hi", sender: users(:pbe_student_3), program: programs(:pbe))

    assert_equal_unordered [req1, req2, req3], group.project_requests
    assert_difference "ProjectRequest.count", -3 do
      group.destroy
    end
  end

  def test_has_many_private_notes
    assert_equal [
        connection_private_notes(:mygroup_student_1),
        connection_private_notes(:mygroup_student_2),
        connection_private_notes(:mygroup_student_3),
        connection_private_notes(:mygroup_mentor_1),
        connection_private_notes(:mygroup_mentor_2)],
      groups(:mygroup).private_notes

    assert_equal [connection_private_notes(:group_2_student_1)],
      groups(:group_2).private_notes
  end

  def test_get_groupees
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    user = users(:f_student)
    user_2 = users(:rahim)
    mentor = users(:f_mentor)

    allow_one_to_many_mentoring_for_program(programs(:albers))
    group = create_group(:students => [user, user_2], :mentors => [mentor], :program => programs(:albers))

    assert_equal [user,user_2], group.get_groupees(mentor)
    assert_equal [user_2, mentor], group.get_groupees(user)
    assert_equal [user, mentor], group.get_groupees(user_2)
    assert_nil group.get_groupees(users(:ram))
    assert_nil group.get_groupees(nil)
  end

  def test_members_by_role
    g = groups(:mygroup)
    assert_equal [:mentors, :mentees, :other_users], g.members_by_role.keys
    assert_equal [g.mentors, g.students, []], g.members_by_role.values
  end

  def test_involving_scope
    student = users(:f_student)
    mentor = users(:f_mentor)
    group = create_group(:students => [student], :mentors => [mentor], :program => programs(:albers))

    some_student = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    some_mentor = create_user(:name => 'some_mentor', :role_names => [RoleConstants::MENTOR_NAME])
    assert_equal [group], Group.involving(student, mentor)
    assert Group.involving(student, some_mentor).empty?
    assert Group.involving(mentor, some_student).empty?

    group.terminate!(users(:f_admin), "Test reason", group.program.permitted_closure_reasons.first.id)
    assert Group.involving(student, mentor).empty?
    assert Group.involving(student, some_mentor).empty?
    assert Group.involving(mentor, some_student).empty?
  end

  def test_pending_more_than_scope
    user = users(:f_student_pbe)
    week_ago = 1.week.ago
    group1 = groups(:group_pbe)
    group2 = groups(:proposed_group_1)

    assert_nil group1.pending_at
    assert_nil group2.pending_at

    group1.update_attribute(:pending_at, week_ago - 10.minutes)
    group2.update_attribute(:pending_at, week_ago + 10.minutes)

    pending_more_than_week_groups = user.groups.pending_more_than(week_ago)
    assert pending_more_than_week_groups.include?(group1)
    assert_false pending_more_than_week_groups.include?(group2)

    group2.update_attribute(:pending_at, week_ago - 20.minutes)
    pending_more_than_week_groups = user.groups.pending_more_than(week_ago)
    assert pending_more_than_week_groups.include?(group2)
  end

  def test_can_be_published
    group = groups(:mygroup)

    group.stubs(:mentors).returns([1])
    group.stubs(:students).returns([2])
    assert group.can_be_published?

    group.stubs(:mentors).returns([])
    group.stubs(:students).returns([2])
    assert_false group.can_be_published?

    group.stubs(:mentors).returns([1])
    group.stubs(:students).returns([])
    assert_false group.can_be_published?

    group.stubs(:mentors).returns([])
    group.stubs(:students).returns([])
    assert_false group.can_be_published?
  end

  def test_with_mentor_and_with_mentee_scope
    student = users(:f_student)
    mentor = users(:f_mentor)
    group = create_group(:students => [student], :mentors => [mentor], :program => programs(:albers))
    first_group = Group.first
    assert_equal [mentor], first_group.mentors

    some_student = create_user(:role_names => [RoleConstants::STUDENT_NAME])
    some_mentor = create_user(:name => 'some_mentor', :role_names => [RoleConstants::MENTOR_NAME])
    assert_equal [first_group, group], Group.with_mentor(mentor)
    assert_equal [group], Group.with_student(student)
    assert Group.with_mentor(some_mentor).empty?
    assert Group.with_student(some_student).empty?
  end

  # In one to Many case
  def test_any_number_of_groups_for_mentor_in_one_to_many
    assert_equal 1, users(:f_mentor).groups.count

    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert_difference 'Group.count' do
      create_group(
        :mentors => [users(:f_mentor)],
        :students => [users(:rahim)],
        :program => programs(:albers))
    end
  end

  # In one to Many case
  def test_allow_many_groups_for_mentor_in_one_to_many_during_group_update
    assert_equal 1, users(:f_mentor).groups.count
    allow_one_to_many_mentoring_for_program(programs(:albers))

    g = create_group(:mentors => [users(:f_mentor_student)], :students => [users(:f_student)], :program => programs(:albers))
    assert_nothing_raised do
      g.mentors = [users(:f_mentor)]
      g.save!
    end

    assert_equal [users(:f_mentor)], g.reload.mentors
  end

  # In one to Many case
  def test_only_one_group_for_mentor_for_with_group_mentoring_allowed
    assert_equal 1, users(:f_mentor).groups.count

    programs(:albers).update_attribute(:allow_one_to_many_mentoring, false)
    assert_difference 'Group.count' do
      create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student)], :program => programs(:albers))
    end
  end

  def test_check_students_count_for_one_to_one
    assert !programs(:albers).allow_one_to_many_mentoring?
    assert_no_difference 'Group.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :students do
        create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student), users(:rahim)], :program => programs(:albers))
      end
    end
  end

  def test_check_for_mentors_mentoring_mode
    # enabling calendar feature for albers program
    org = Program::Domain.get_organization(DEFAULT_DOMAIN_NAME,"primary")
    org.enable_feature(FeatureName::CALENDAR,true)

    # changing allow mentoring mode for albers program
    programs(:albers).update_attribute(:allow_mentoring_mode_change, Program::MENTORING_MODE_CONFIG::EDITABLE)
    programs(:albers).reload

    # testing one to one group creation
    assert_difference 'Group.count', +1 do
      create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student)], :program => programs(:albers))
    end

    # testing many to one group creation
    assert_difference 'Group.count', +1 do
      create_group(:mentors => [users(:mentor_2), users(:mentor_3)], :students => [users(:f_student)], :program => programs(:albers))
    end

    # testing one to one group creation error when mentor has one time mentoring mode
    users(:f_mentor).update_attribute(:mentoring_mode,User::MentoringMode::ONE_TIME)
    users(:f_mentor).reload
    group = Group.new(:mentors => [users(:f_mentor)], :students => [users(:rahim)], :program => programs(:albers))
    assert_false group.valid?
    assert group.errors[:base].include?("#{users(:f_mentor).name} has preferred to participate only in One time mentoring")

    # testing many to one group creation error when one mentor has one time mentoring mode
    users(:mentor_3).update_attribute(:mentoring_mode,User::MentoringMode::ONE_TIME)
    users(:mentor_3).reload
    group = Group.new(:mentors => [users(:mentor_3),users(:mentor_4)], :students => [users(:rahim)], :program => programs(:albers))
    assert_false group.valid?
    assert group.errors[:base].include?("#{users(:mentor_3).name} has preferred to participate only in One time mentoring")

    # testing add/remove members by adding mentor preferring one time mentoring
    group = Group.where(:program_id => programs(:albers).id).first
    group.update_members(group.mentors + [users(:mentor_3)], group.students)
    assert group.errors[:base].include?("#{users(:mentor_3).name} has preferred to participate only in One time mentoring")

    # testing for other than update member scenario
    group = Group.where(:program_id => programs(:albers).id).first
    assert group.members_by_role[:mentors].include?(users(:f_mentor))
    users(:f_mentor).update_attribute(:mentoring_mode,User::MentoringMode::ONE_TIME)
    group.update_attribute(:name, "test name")

    assert_false group.errors[:base].present?
  end

  def test_validates_presence_of_name
    g = groups(:mygroup)
    g.name = nil
    assert_false g.valid?
    assert_equal ["can't be blank"], g.errors[:name]
    g.name = "test"
    assert g.valid?
  end

  def test_validate_status
    g = groups(:mygroup)
    assert_equal Group::Status::ACTIVE, g.status
    assert g.valid?

    g.status = Group::Status::INACTIVE
    assert g.valid?

    g.status = Group::Status::DRAFTED
    assert g.valid?

    g.status = 10
    assert_false g.valid?

    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    assert g.valid?
  end

  def test_validates_presence_of_created_by
    g1 = groups(:drafted_group_1)
    g2 = groups(:drafted_group_2)
    g1.created_by = nil
    g2.created_by = nil
    g2.status = Group::Status::PROPOSED
    g1.update_attribute(:expiry_time, 1.day.from_now)
    g2.update_attribute(:expiry_time, 1.day.from_now)
    assert g1.valid?
    assert g2.valid?

    assert_no_difference 'Group.count' do
      assert_raise ActiveRecord::RecordInvalid, "Created by can't be blank" do
        Group.create!(
          :mentors => [users(:f_mentor)],
          :students => [users(:f_student)],
          :program => programs(:albers),
          :status => Group::Status::DRAFTED
        )
      end
    end

    assert_no_difference 'Group.count' do
      assert_raise ActiveRecord::RecordInvalid, "Created by can't be blank" do
        Group.create!(
          :mentors => [users(:f_mentor)],
          :students => [users(:f_student)],
          :program => programs(:albers),
          :status => Group::Status::PROPOSED
        )
      end
    end
  end

  def test_created_by_sorting
    all_creator_names = Group.all.map{|g| g.created_by.try(:name)}.compact
    assert_equal all_creator_names.sort, Group.get_filtered_groups({sort: { "created_by.name_only.sort": "asc"}, per_page: 1000}).map{|g| g.created_by.try(:name)}.compact
    assert_equal all_creator_names.sort.reverse, Group.get_filtered_groups({sort: { "created_by.name_only.sort": "desc"}, per_page: 1000}).map{|g| g.created_by.try(:name)}.compact
  end

  def test_closed_by_sorting
    groups = Group.first(4)
    user_ids = User.first(4).map(&:id)
    groups.each_with_index{|group, index| group.update_attributes(terminator_id: user_ids[index])}
    reindex_documents(updated: groups)

    all_terminator_names = Group.all.map{|g| g.closed_by.try(:name)}.compact
    assert_equal all_terminator_names.sort.reverse, Group.get_filtered_groups({sort: { "closed_by.name_only.sort": "desc"}, per_page: 1000}).map{|g| g.closed_by.try(:name)}.compact
    assert_equal all_terminator_names.sort, Group.get_filtered_groups({sort: { "closed_by.name_only.sort": "asc"}, per_page: 1000}).map{|g| g.closed_by.try(:name)}.compact
  end

  def test_check_mentee_limit_of_mentor_validation_for_creation
    users(:f_mentor).update_attribute(:max_connections_limit, 1)
    users(:f_mentor).reload
    @g = Group.new(:mentors => [users(:f_mentor)], :students => [users(:f_student)], :program => programs(:albers))
    assert_false @g.valid?
    assert_equal ["#{users(:f_mentor).name} preferred not to have more than 1 students"], @g.errors[:base]
  end

  def test_check_mentee_limit_of_mentor_validation_for_drafted_group_creation
    users(:f_mentor).update_attribute(:max_connections_limit, 1)
    users(:f_mentor).reload
    @g = Group.new(:mentors => [users(:f_mentor)], :students => [users(:f_student)], :program => programs(:albers), :status => Group::Status::DRAFTED)
    assert_false @g.valid?
    assert_equal ["#{users(:f_mentor).name} preferred not to have more than 1 students"], @g.errors[:base]
  end

  def test_check_mentee_limit_of_mentor_validation_for_updating_active_connection
    users(:f_mentor).update_attribute(:max_connections_limit, 2)
    users(:f_mentor).reload
    g = create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student)], :program => programs(:albers))
    assert_equal Group::Status::ACTIVE, g.status

    g.students = [users(:f_student), users(:rahim)]
    assert_false g.valid?
    assert_equal ["#{users(:f_mentor).name} preferred not to have more than 2 students"], g.errors[:base]
  end

  def test_check_mentee_limit_of_mentor_validation_for_reactivating_connection_and_for_a_closed_connection
    # users(:f_mentor) already has one group in groups.yml
    users(:f_mentor).update_attribute(:max_connections_limit, 2)
    users(:f_mentor).reload

    g1 = create_group(:mentors => [users(:f_mentor)], :students => [users(:f_student)], :program => programs(:albers))
    g1.terminate!(users(:f_admin), 'this is the reason', g1.program.permitted_closure_reasons.first.id)
    assert g1.reload.closed?

    g1.member_added = false
    users(:f_mentor).update_attribute(:max_connections_limit, 1)
    users(:f_mentor).reload

    assert g1.valid?

    g1.change_expiry_date(users(:f_admin), g1.expiry_time+3.months, "Peace")
    assert !g1.valid?
    assert g1.reload.closed?
  end

  def test_terminate
    g = groups(:mygroup)
    assert_difference 'Group.active.size', -1 do
      g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    end
    g.reload
    assert_false g.active?
    assert_equal "Test reason", g.termination_reason
    assert_equal users(:f_admin), g.closed_by
    assert_not_nil g.closed_at
    assert_equal Group::Status::CLOSED, g.status
    assert_equal Group::TerminationMode::ADMIN, g.termination_mode

    # Termination by non-admin or other program's admin should fail.
    g = create_group(:program => programs(:albers))
    assert_no_difference 'Group.active.size' do
      assert_raise ActiveRecord::RecordInvalid do
        g.terminate!(users(:f_mentor), "New reason", g.program.permitted_closure_reasons.first.id)
      end

      g.reload
      assert_equal ["The user is not authorized to terminate the mentoring connection"], g.errors[:base]

      assert_raise ActiveRecord::RecordInvalid do
        g.terminate!(users(:moderated_admin), "New reason", g.program.permitted_closure_reasons.first.id)
      end
      g.reload
      assert_equal ["The user is not authorized to terminate the mentoring connection"], g.errors[:base]

      assert_raise_error_on_field ActiveRecord::RecordInvalid, :closed_at do
        g.status =  Group::Status::CLOSED
        g.save!
      end
    end

    g.terminate!(users(:ram), "New reason", g.program.permitted_closure_reasons.first.id)
    g.reload
    assert_false g.active?
    assert_equal "New reason", g.termination_reason
    assert_equal users(:ram), g.closed_by
    assert_not_nil g.closed_at
  end

  def test_terminate_action_for
    g = create_group(:mentors => [users(:f_mentor_pbe)], :students => [], :program => programs(:pbe), :status => Group::Status::PENDING )
    assert_equal Group::Status::PENDING, g.status
    assert_equal 1, g.members.size
    assert_false g.is_terminate_action_for?(users(:f_mentor_pbe))
  end

  def test_terminate_by_owner
    g = groups(:mygroup)
    make_user_owner_of_group(g, users(:f_mentor))
    g.terminate!(users(:f_mentor), "Test reason", g.program.permitted_closure_reasons.first.id)
    g.reload
    assert_false g.active?
    assert_equal "Test reason", g.termination_reason
    assert_equal users(:f_mentor), g.closed_by
    assert_not_nil g.closed_at
    assert_equal Group::Status::CLOSED, g.status
    assert_equal Group::TerminationMode::ADMIN, g.termination_mode
  end

  def test_reactivate
    g = groups(:mygroup)
    g.set_member_status(g.membership_of(users(:f_mentor)), Connection::Membership::Status::INACTIVE)
    assert_equal Connection::Membership::Status::INACTIVE, g.reload.member_status(users(:f_mentor))

    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    assert_false g.reload.active?
    assert_equal g.termination_reason, "Test reason"

    expiry_time = (Time.now + 2.months).utc
    assert_emails 2 do
      assert_difference "RecentActivity.count" do
        g.change_expiry_date(users(:f_admin), expiry_time, "Peace")
      end
    end
    assert g.reload.active?
    assert_equal Connection::Membership::Status::ACTIVE, g.member_status(users(:f_mentor))
    assert_time_string_equal expiry_time.to_date.end_of_day.utc, g.expiry_time.utc
    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::GROUP_REACTIVATION, ra.action_type
    assert_equal users(:f_admin), ra.get_user(programs(:albers))
    assert_equal RecentActivityConstants::Target::ALL, ra.target
  end

  def test_change_expiry_date
    g = groups(:mygroup)
    new_expiry_time = Time.zone.now  +  2.months

    assert_pending_notifications 2 do
      assert_difference "RecentActivity.count" do
        g.change_expiry_date(users(:f_admin), new_expiry_time,"Test Reason")
      end
    end
    assert_equal new_expiry_time.to_date.end_of_day.to_s, g.reload.expiry_time.to_s
    ra = RecentActivity.last
    assert_equal RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, ra.action_type
    assert_equal users(:f_admin), ra.get_user(programs(:albers))
    assert_equal RecentActivityConstants::Target::ALL, ra.target
  end

  def test_change_expiry_date_with_clear_closure_reason
    g = groups(:group_4)
    new_expiry_time = Time.zone.now  +  2.months

    assert g.closure_reason.present?
    assert_pending_notifications 0 do
      assert_difference "RecentActivity.count" do
        g.change_expiry_date(users(:f_admin), new_expiry_time,"Test Reason", {:clear_closure_reason => true})
      end
    end
    assert_equal new_expiry_time.to_date.end_of_day.to_s, g.reload.expiry_time.to_s
    ra = RecentActivity.last
    assert_false g.closure_reason.present?
    assert_equal users(:f_admin), ra.get_user(programs(:albers))
    assert_equal RecentActivityConstants::Target::ALL, ra.target
  end

  def test_change_expiry_date_with_no_mentee
    g = groups(:group_4) # terminated group
    new_expiry_time = Time.now + 2.months
    student = users(:student_4)
    student.role_names += ['mentor']
    student.demote_from_role!(['student'],users(:f_admin))

    assert_false g.change_expiry_date(users(:f_admin), new_expiry_time, "Test Reason")
    assert g.errors.full_messages.to_sentence.include?("activerecord.custom_errors.membership.cannot_be_mentee_v1".translate(user_name: student.name, mentee: student.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).articleized_term_downcase))
  end

  def test_change_expiry_date_with_no_mentee_for_bulk_action
    g = groups(:group_4)
    new_expiry_time = Time.now + 2.months
    student = users(:student_4)
    student.role_names += ['mentor']
    student.demote_from_role!(['student'],users(:f_admin))
    Group.expects(:make_all_group_members_active).once
    assert g.change_expiry_date(users(:f_admin), new_expiry_time, "Test Reason", {for_bulk_change_expiry_date: true})
  end

  def test_mark_all_group_member_active_with_no_mentee
    g = groups(:group_4)
    new_expiry_time = Time.now + 2.months
    student = users(:student_4)
    student.role_names += ['mentor']
    student.demote_from_role!(['student'],users(:f_admin))
    errors = Group.make_all_group_members_active(g.id)
    assert errors, ["activerecord.custom_errors.membership.cannot_be_mentee_v1".translate(user_name: student.name, mentee: student.program.term_for(CustomizedTerm::TermType::ROLE_TERM, RoleConstants::STUDENT_NAME).articleized_term_downcase)]
  end

  def test_mark_all_group_member_active_with_no_mentee_with_notify_airbrake
    g = groups(:group_4)
    new_expiry_time = Time.now + 2.months
    student = users(:student_4)
    student.role_names += ['mentor']
    student.demote_from_role!(['student'],users(:f_admin))
    # If notify_airbrake is set true then no errors will be set to group and if any error it will be notified in airbrake
    Airbrake.expects(:notify).once
    assert Group.make_all_group_members_active(g.id, true)
  end

  def test_change_expiry_date_invalid_date
    g = groups(:mygroup)
    old_expiry_time = g.expiry_time.utc.to_s
    new_expiry_time = Time.now  -  2.months
    g.change_expiry_date(users(:f_admin), new_expiry_time, "Test Reason")
    assert_equal old_expiry_time, g.reload.expiry_time.utc.to_s
    assert_equal g.errors.full_messages , ["Invalid expiration date"]

    g.change_expiry_date(users(:f_admin), "dsadsad", "Test Reason")
    assert_equal old_expiry_time, g.reload.expiry_time.utc.to_s
    assert_equal g.errors.full_messages , ["Expires on can't be blank","Invalid expiration date"]

    g.change_expiry_date(users(:f_admin), "", "Test Reason")
    assert_equal old_expiry_time, g.reload.expiry_time.utc.to_s
    assert_equal g.errors.full_messages , ["Expires on can't be blank","Invalid expiration date"]
  end

  def test_expired
    g = groups(:mygroup)

    g.update_attribute(:expiry_time, 1.day.from_now)
    assert(!g.expired?)

    g.update_attribute(:expiry_time, 1.day.ago)
    assert(g.expired?)
  end

  def test_published_drafted
    g = groups(:drafted_group_1)
    g1 = groups(:mygroup)

    assert g.drafted?
    assert_false g.published?

    assert_false g1.drafted?
    assert g1.published?
  end

  def test_publish_published
    g1 = groups(:mygroup)
    assert g1.published?
    assert g1.publish(users(:f_admin), "test message")
  end

  def test_inactive
    g = groups(:mygroup)
    assert !g.inactive?

    g.update_attribute(:status, Group::Status::INACTIVE)
    assert g.inactive?
  end

  def test_pending_or_active
    g = groups(:mygroup)
    assert g.pending_or_active?

    g.update_attribute(:status, Group::Status::PENDING)
    assert g.pending_or_active?

    g.update_attribute(:status, Group::Status::INACTIVE)
    assert g.pending_or_active?

    g.update_attribute(:status, Group::Status::DRAFTED)
    assert_false g.pending_or_active?

    g.update_attribute(:status, Group::Status::PROPOSED)
    assert_false g.pending_or_active?

    g.update_attribute(:status, Group::Status::WITHDRAWN)
    assert_false g.pending_or_active?
  end

  def test_closed_or_expired
    g = groups(:mygroup)

    g.update_attribute(:expiry_time, 1.day.from_now)
    assert(!g.expired?)
    assert(!g.closed?)
    assert(!g.closed_or_expired?)

    g.update_attribute(:expiry_time, 1.day.ago)
    assert(g.expired?)
    assert(!g.closed?)
    assert(g.closed_or_expired?)

    g.update_attribute(:expiry_time, 1.day.from_now)
    assert(!g.expired?)
    g.terminate!(users(:f_admin), 'some reason', g.program.permitted_closure_reasons.first.id)
    assert(g.closed?)
    assert(g.closed_or_expired?)

    g.update_attribute(:expiry_time, 1.day.ago)
    assert(g.expired?)
    assert(g.closed?)
    assert(g.closed_or_expired?)
  end

  def test_open
    group = groups(:mygroup)
    open_statuses = [Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::PENDING]

    assert open_statuses.all? do |status|
      group.status = status
      group.open?
    end

    result = (Group::Status.all.to_a - open_statuses).any? do |status|
      group.status = status
      group.open?
    end
    assert_false result
  end

  def test_about_to_expire
    g = groups(:mygroup)

    g.update_attribute(:expiry_time, 1.week.from_now)
    assert(!g.expired?)
    assert(g.about_to_expire?)

    g.update_attribute(:expiry_time, 11.days.from_now)
    assert(!g.expired?)
    assert(g.about_to_expire?)

    g.update_attribute(:expiry_time, 3.weeks.from_now)
    assert(!g.expired?)
    assert(!g.about_to_expire?)
  end

  def test_expiring_next_week
    g = groups(:mygroup)

    g.update_attribute(:expiry_time, 1.day.from_now)
    assert(!g.expired?)
    assert(g.expiring_next_week?)

    g.update_attribute(:expiry_time, 5.days.from_now)
    assert(!g.expired?)
    assert(g.expiring_next_week?)

    g.update_attribute(:expiry_time, 3.weeks.from_now)
    assert(!g.expired?)
    assert(!g.expiring_next_week?)
  end

  def test_recently_reactivated
    RecentActivity.destroy_all
    g = groups(:mygroup)
    assert !g.recently_reactivated?

    ra =  RecentActivity.create!(
    :programs => [groups(:mygroup).program],
      :ref_obj => groups(:mygroup),
      :action_type => RecentActivityConstants::Type::GROUP_REACTIVATION,
      :member => groups(:mygroup).mentors.first.member,
      :target => RecentActivityConstants::Target::ALL)

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD - 1.hour)
    assert !g.recently_reactivated?

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD + 1.hour)
    assert g.recently_reactivated?
  end

  def test_recently_expiry_date_changed
    RecentActivity.destroy_all
    g = groups(:mygroup)
    assert !g.recently_expiry_date_changed?

    ra = RecentActivity.create!(
   :programs => [groups(:mygroup).program],
      :ref_obj => groups(:mygroup),
      :action_type => RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
      :member => groups(:mygroup).mentors.first.member,
      :target => RecentActivityConstants::Target::ALL)

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD - 1.hour)
    assert !g.recently_expiry_date_changed?

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD + 1.hour)
    assert g.recently_expiry_date_changed?
  end

  def test_show_notice
    g = groups(:mygroup)

    g.update_attribute(:expiry_time, 11.days.from_now)
    assert g.about_to_expire?
    assert g.show_notice?

    g.update_attribute(:expiry_time, 1.day.ago)
    assert g.expired?
    assert g.show_notice?

    RecentActivity.destroy_all
    assert !g.recently_reactivated?

    ra = RecentActivity.create!(
   :programs => [groups(:mygroup).program],
      :ref_obj => groups(:mygroup),
      :action_type => RecentActivityConstants::Type::GROUP_REACTIVATION,
      :member => groups(:mygroup).mentors.first.member,
      :target => RecentActivityConstants::Target::ALL)

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD + 1.hour)
    assert g.recently_reactivated?
    assert g.show_notice?

    RecentActivity.destroy_all
    assert !g.recently_expiry_date_changed?

    ra = RecentActivity.create!(
   :programs => [groups(:mygroup).program],
      :ref_obj => groups(:mygroup),
      :action_type => RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE,
      :member => groups(:mygroup).mentors.first.member,
      :target => RecentActivityConstants::Target::ALL)

    ra.update_attribute(:created_at, Time.now - Group::EXTENSION_NOTICE_SERVING_PERIOD + 1.hour)
    assert g.recently_expiry_date_changed?
    assert g.show_notice?

    g.stubs(:closed?).returns(true)
    assert g.expired?
    assert g.show_notice?

    g.update_attribute(:expiry_time, 11.days.from_now)
    assert_false g.expired?
    assert g.about_to_expire?
    assert_false g.show_notice?
  end

  def test_mentor_request_update_on_group_create
    users(:ram).update_attribute(:max_connections_limit, 5)
    allow_one_to_many_mentoring_for_program(programs(:moderated_program))
    make_member_of(:moderated_program, :ram)
    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :f_mentor_student)

    m1 = create_mentor_request(:student => users(:f_student), :mentor => nil, :program => programs(:moderated_program))
    m2 = create_mentor_request(:student => users(:f_mentor_student), :mentor => nil, :program => programs(:moderated_program))

    assert_equal m1.status, AbstractRequest::Status::NOT_ANSWERED
    assert_equal m2.status, AbstractRequest::Status::NOT_ANSWERED

    assert_difference 'Group.count' do
      create_group(:students => [users(:f_student), users(:f_mentor_student)], :mentors => [users(:ram)], :program => programs(:moderated_program))
    end
  end

  def test_mentor_request_update_on_group_update
    p = programs(:moderated_program)
    allow_one_to_many_mentoring_for_program(p)
    make_member_of(:moderated_program, :f_student)
    make_member_of(:moderated_program, :f_mentor_student)

    users(:moderated_mentor).update_attribute(:max_connections_limit, 3)

    m1 = create_mentor_request(:student => users(:f_student), :mentor => nil, :program => p)
    m2 = create_mentor_request(:student => users(:f_mentor_student), :mentor => nil, :program => p)

    assert_equal m1.status, AbstractRequest::Status::NOT_ANSWERED
    assert_equal m2.status, AbstractRequest::Status::NOT_ANSWERED

    g = create_group(:mentors => [users(:moderated_mentor)], :students => [users(:moderated_student)], :program => p)
    assert_no_difference 'Group.count' do
      g.all_old_students = g.students.clone
      g.students << [users(:f_student), users(:f_mentor_student)]
      g.save!
    end
  end

  def test_has_activities
    RecentActivity.destroy_all
    group = groups(:mygroup)
    student = group.students.first
    Scrap.destroy_all
    assert !group.has_activities?
    scrap = create_scrap(:group => group)
    assert group.reload.has_activities?
    scrap.destroy
    # No activities now.
    assert !group.reload.has_activities?
  end

  def test_activity_feed
    RecentActivity.destroy_all
    group = groups(:mygroup)
    student = group.students.first
    Scrap.destroy_all
    i = 0

    # While testing, all activities time will be same. So, shift them
    # so that they are different.
    shift_time = lambda do |obj|
      ActiveRecord::Base.skip_timestamping do
        obj.update_attribute :created_at, Time.now + i.days
      end

      i += 1
    end

    assert group.activity_feed.empty?

    activities = group.activities

    create_scrap(:group => group)
    shift_time.call(activities.last)
    activities = group.activities
    # Scrap is NOT for display in the activity feed
    assert_not_equal activities.last(3).reverse, group.reload.activity_feed
    assert_equal activities.last(3).reverse[1..2], group.reload.activity_feed
  end

  def test_get_tasks_list
    group = groups(:mygroup)
    assert_equal 2, group.meetings.size
    assert_equal 0, group.mentoring_model_tasks.size
    time = group.meetings[0].start_time
    t1 = create_mentoring_model_task(due_date: time - 6.days, required: true)
    t2 = create_mentoring_model_task(due_date: time + 6.days, required: true)
    meeting = group.meetings[0]
    merged_task_list = group.reload.get_tasks_list
    assert_equal t1, merged_task_list.first
    assert_equal t2, merged_task_list.last
    assert_false merged_task_list.include?(meeting)
  end

  def test_get_tasks_list_for_sort_by_due_date
    group = groups(:mygroup)
    group.meetings.destroy_all
    task1 = create_mentoring_model_task(required: true, due_date: group.published_at + 5.days, position: 0)
    task2 = create_mentoring_model_task(required: false, position: 1)
    task3 = create_mentoring_model_task(required: true, due_date: group.published_at + 10.days, position: 2)
    merged_task_list = group.reload.get_tasks_list([], view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE)
    assert_equal [task1, task3, task2], merged_task_list
  end

  def test_get_tasks_list_with_milestones
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    group = groups(:mygroup)
    assert_equal 2, group.meetings.size
    assert_equal 0, group.mentoring_model_tasks.size
    time = group.meetings[0].start_time
    t1 = create_mentoring_model_task
    t1.update_attributes!(due_date: time - 6.days, required: true, milestone_id: milestone1.id)
    t2 = create_mentoring_model_task
    t2.update_attributes!(due_date: time + 6.days, required: true, milestone_id: milestone2.id)
    items_list = group.reload.get_tasks_list([], milestones_enabled: true)
    assert_equal t1, items_list.first
    assert_equal t2, items_list.last
  end

  def test_get_tasks_list_with_target_user
    group = groups(:mygroup)
    assert_equal 2, group.meetings.size
    assert_equal 0, group.mentoring_model_tasks.size
    time = group.meetings[0].start_time
    members = group.members.to_a

    t1 = create_mentoring_model_task(due_date: time - 6.days, required: true, user: members.first)
    t2 = create_mentoring_model_task(due_date: time + 6.days, required: true, user: members.last)
    meeting = group.meetings[0]
    merged_task_list = group.reload.get_tasks_list
    assert_equal t1, merged_task_list.first
    assert_equal t2, merged_task_list.last
    merged_task_list = group.reload.get_tasks_list([], target_user: members.first)
    assert_equal t1, merged_task_list.first
    assert_not_equal t2, merged_task_list.last
  end

  def test_get_tasks_list_home_page_view
    group = groups(:mygroup)
    user = users(:f_mentor)
    assert_equal 0, group.mentoring_model_tasks.size
    
    task1 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days)
    task2 = create_mentoring_model_task(required: true, due_date: Date.today + 5.days)
    task3 = create_mentoring_model_task(required: true, due_date: Date.today + 15.days)
    task4 = create_mentoring_model_task(user: users(:mkr_student))
    task5 = create_mentoring_model_task(required: true, due_date: 1.day.ago, status: MentoringModel::Task::Status::DONE)

    
    assert_equal [task1, task2], group.get_tasks_list([], target_user: user, home_page_view: true)
    task1.update_column(:due_date, Time.now + 15.days)
    assert_equal [task2], group.get_tasks_list([], target_user: user, home_page_view: true)
    task2.update_column(:due_date, Time.now + 15.days)
    assert_equal [], group.get_tasks_list([], target_user: user, home_page_view: true)
    task3.update_column(:due_date, Time.now - 15.days)
    assert_equal [task3], group.get_tasks_list([], target_user: user, home_page_view: true)
  end

  def test_get_tasks_list_with_target_user_sort_by_due_date
    group = groups(:mygroup)
    group.meetings.destroy_all
    members = group.members.to_a
    task1 = create_mentoring_model_task(required: true, due_date: group.published_at + 5.days, position: 0, user: members.first)
    task2 = create_mentoring_model_task(required: false, position: 1, user: members.last)
    task3 = create_mentoring_model_task(required: true, due_date: group.published_at + 10.days, position: 2, user: members.first)
    merged_task_list = group.reload.get_tasks_list([], view_mode: MentoringModelUtils::ViewMode::SORT_BY_DUE_DATE, target_user: members.first)
    assert_equal [task1, task3], merged_task_list
  end

  def test_set_task_positions
    group = groups(:mygroup)
    members = group.members.to_a

    task_1 = create_mentoring_model_task(required: true, due_date: group.published_at + 15.days)
    task_2 = create_mentoring_model_task(required: false)
    task_3 = create_mentoring_model_task(required: true, due_date: group.published_at + 10.days)
    group.set_task_positions
    assert_equal 1, task_1.reload.position
    assert_equal 2, task_2.reload.position
    assert_equal 0, task_3.reload.position

    milestone = create_mentoring_model_milestone
    task_4 = create_mentoring_model_task(required: false, milestone: milestone)
    task_5 = create_mentoring_model_task(required: true, due_date: group.published_at + 5.days, milestone: milestone)
    task_6 = create_mentoring_model_task(required: true, due_date: group.published_at + 7.days, milestone: milestone)
    group.reload.set_task_positions
    # Group-tied tasks
    assert_equal 1, task_1.reload.position
    assert_equal 2, task_2.reload.position
    assert_equal 0, task_3.reload.position
    # Milestone-tied tasks
    assert_equal 2, task_4.reload.position
    assert_equal 0, task_5.reload.position
    assert_equal 1, task_6.reload.position

    task_7 = create_mentoring_model_task(required: true, due_date: group.published_at + 6.days, milestone: milestone)
    task_template = create_mentoring_model_task_template(position: 10)
    task_8 = create_mentoring_model_task(required: false, from_template: true, mentoring_model_task_template_id: task_template.id, milestone: milestone)
    group.reload.set_task_positions
    # Group-tied tasks
    assert_equal 1, task_1.reload.position
    assert_equal 2, task_2.reload.position
    assert_equal 0, task_3.reload.position
    # Milestone-tied tasks
    assert_equal 4, task_4.reload.position
    assert_equal 0, task_5.reload.position
    assert_equal 2, task_6.reload.position
    assert_equal 1, task_7.reload.position
    assert_equal 3, task_8.reload.position
  end

  def test_mark_active
    g = groups(:mygroup)
    g.update_attribute(:status, Group::Status::INACTIVE)
    g.reload
    assert_equal Group::Status::INACTIVE, g.status

    g.mark_active!
    g.reload
    assert_equal Group::Status::ACTIVE, g.status

    g.terminate!(users(:f_admin), 'some reason', g.program.permitted_closure_reasons.first.id)
    assert g.closed?
    g.mark_active!
    assert g.reload.closed?
  end

  def test_check_closed_by_set_when_manual_termination
    g = groups(:mygroup)
    g.termination_mode = Group::TerminationMode::ADMIN
    g.closed_by = nil
    g.status = Group::Status::CLOSED
    assert_raise ActiveRecord::RecordInvalid do
      g.save!
    end
  end

  def test_validation_closed_by_and_termination_reason_for_rejected_group
    g = groups(:drafted_group_1)
    g.status = Group::Status::REJECTED
    g.created_by = nil
    g.termination_reason = nil
    g.closed_at = nil
    assert_false g.valid?
    assert_equal ["can't be blank"], g.errors[:closed_by]
    assert_equal ["can't be blank"], g.errors[:closed_at]
    g.closed_by = users(:f_admin)
    g.termination_reason = "sample reason"
    g.closed_at = Time.now
    assert g.valid?
  end

  def test_validation_for_withdrawn_group
    g = groups(:drafted_group_1)
    g.status = Group::Status::WITHDRAWN
    g.created_by = nil
    g.termination_reason = nil
    g.closed_at = nil
    assert_false g.valid?
    assert_equal ["can't be blank"], g.errors[:closed_by]
    assert_equal ["can't be blank"], g.errors[:closed_at]
    assert_equal ["can't be blank"], g.errors[:termination_reason]
    g.closed_by = users(:f_admin)
    g.termination_reason = "sample reason"
    g.closed_at = Time.now
    assert g.valid?
  end

  def test_with_status_scope
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    g3 = groups(:group_3)
    g4 = groups(:group_4) # Terminated by default
    g5 = groups(:group_5)
    g6 = groups(:group_inactive)
    g7 = groups(:multi_group)
    g8 = groups(:group_nwen)
    g9 = groups(:old_group)
    g10 = groups(:drafted_group_1)
    g11 = groups(:drafted_group_2)
    g12 = groups(:drafted_group_3)
    g13 = groups(:no_mreq_group)
    group_default_scope = "groups.program_id != #{programs(:pbe).id}"

    [g1, g2, g3, g5, g7, g8, g13].each do |group|
      assert group.active? && !group.inactive?
    end
    assert g4.closed?
    assert g6.inactive?

    [g10, g11].each do |group|
      assert group.drafted? && !group.published?
    end

    assert_equal [g1, g2, g3, g5, g7, g8, g9, g13],  Group.where(group_default_scope).with_status(Group::Status::ACTIVE)
    assert_equal [g6],  Group.where(group_default_scope).with_status(Group::Status::INACTIVE)
    assert_equal [g4],  Group.where(group_default_scope).with_status(Group::Status::CLOSED)

    assert_equal [g10, g11, g12],  Group.where(group_default_scope).with_status(Group::Status::DRAFTED)
    assert_equal [g1, g2, g3, g5, g6, g7, g8, g9, g13],  Group.where(group_default_scope).with_status([Group::Status::ACTIVE, Group::Status::INACTIVE])
    assert_equal [g1, g2, g3, g4, g5, g6, g7, g8, g9, g13],  Group.where(group_default_scope).with_status([Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::CLOSED])
  end

  def test_active_or_drafted_scope
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    g3 = groups(:group_3)
    g4 = groups(:group_5)
    g5 = groups(:multi_group)
    g6 = groups(:group_nwen)
    g7 = groups(:drafted_group_1)
    g8 = groups(:drafted_group_2)
    g9 = groups(:drafted_group_3)
    g10 = groups(:old_group)
    #active groups are groups which are NOT CLOSED. Even INACTIVE groups will be counted as ACTIVE groups.
    g11 = groups(:group_inactive)
    g12 = groups(:no_mreq_group)
    pbe_group = groups(:group_pbe)
    drafted_pbe_group = groups(:drafted_pbe_group)

    [g1, g2, g3, g4, g5, g6, g10, g12].each do |group|
      assert group.active? && !group.inactive?
    end

    assert g11.active? && g11.inactive?

    [g7, g8, g9, drafted_pbe_group].each do |group|
      assert group.drafted? && !group.published?
    end

    assert_equal_unordered [g1, g2, g3, g4, g5, g6, g7, g8, g9, g10, g11, g12, pbe_group, drafted_pbe_group], Group.active_or_drafted
  end

  def test_active_or_closed
    g1 = groups(:mygroup)
    g2 = groups(:group_2)
    g3 = groups(:group_3)
    g4 = groups(:group_4)
    g5 = groups(:group_5)
    g6 = groups(:group_inactive)
    g7 = groups(:old_group)

    assert_equal_unordered [g1, g2, g3, g4, g5, g6, g7], programs(:albers).groups.active_or_closed
  end

  def test_expired_scope
    p = programs(:albers)
    p.update_attribute(:mentoring_period, 2.months)
    g = groups(:mygroup)

    assert !g.expired?
    assert Group.expired.blank?

    g.update_attribute(:expiry_time, 2.hours.from_now)
    assert !g.expired?
    assert Group.expired.blank?

    g.update_attribute(:expiry_time, 2.hours.ago)
    assert g.expired?
    assert_equal [g], Group.expired

    g.update_attribute(:expiry_time, 2.months.ago)
    assert g.expired?
    assert_equal [g], Group.expired
  end

  def test_global_scope
    p = programs(:albers)
    assert_equal [groups(:mygroup), groups(:group_2)], p.groups.global

    g = groups(:group_3)
    g.global = true
    g.save!

    assert_equal [groups(:mygroup), groups(:group_2), groups(:group_3)], p.reload.groups.global
  end

  def test_with_overdue_tasks_scope
    p = programs(:albers)
    assert_equal [], p.groups.with_overdue_tasks

    group = groups(:mygroup)

    assert group.mentoring_model_tasks.empty?
    mmt = group.mentoring_model_tasks.create!(:title => 'some text', :required => true, :status => MentoringModel::Task::Status::TODO, :due_date => 1.week.ago)
    assert p.reload.groups.with_overdue_tasks.include?(groups(:mygroup))

    mmt.update_attributes!(:required => false)
    assert_false p.reload.groups.with_overdue_tasks.include?(groups(:mygroup))

    mmt.update_attributes!(:required => true, :status => MentoringModel::Task::Status::DONE, :due_date => 1.week.ago)
    assert_false p.reload.groups.with_overdue_tasks.include?(groups(:mygroup))

    mmt.update_attributes!(:status => MentoringModel::Task::Status::TODO, :due_date => 1.week.from_now)
    assert_false p.reload.groups.with_overdue_tasks.include?(groups(:mygroup))
  end

  def test_can_be_activated
    assert !groups(:mygroup).can_be_activated?
    groups(:mygroup).update_attribute :status, Group::Status::INACTIVE
    assert groups(:mygroup).can_be_activated?
    groups(:mygroup).terminate!(users(:f_admin), 'Some reason', groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert !groups(:mygroup).can_be_activated?
  end

  def test_mark_visit
    # Only members can visit
    assert_no_difference ['RecentActivity.count', 'ActivityLog.count'] do
      groups(:mygroup).mark_visit(users(:student_3))
    end

    assert_difference ['RecentActivity.count', 'ActivityLog.count'], 1 do
      groups(:mygroup).mark_visit(groups(:mygroup).mentors.first)
    end

    act = RecentActivity.last
    assert_equal RecentActivityConstants::Type::VISIT_MENTORING_AREA, act.action_type
    assert_equal RecentActivityConstants::Target::NONE, act.target
    assert_equal groups(:mygroup), act.ref_obj
    assert_equal users(:f_mentor), act.get_user(programs(:albers))

    # Subsequent visits will also create RA's
    assert_difference 'RecentActivity.count' do
      groups(:mygroup).mark_visit(groups(:mygroup).mentors.first)
    end

    assert_difference 'RecentActivity.count' do
      groups(:mygroup).mark_visit(groups(:mygroup).students.first)
    end

    act = RecentActivity.last
    assert_equal RecentActivityConstants::Type::VISIT_MENTORING_AREA, act.action_type
    assert_equal RecentActivityConstants::Target::NONE, act.target
    assert_equal groups(:mygroup), act.ref_obj
    assert_equal groups(:mygroup).students.first, act.get_user(programs(:albers))
  end

  def test_has_many_activities
    RecentActivity.destroy_all
    group = groups(:mygroup)
    student = groups(:mygroup).students.first
    assert group.activities.empty?

    group.expiry_time = group.expiry_time + 1.day
    group.save!
    expiry_time_change_act = RecentActivity.last

    group.reload.mark_visit(student)
    student_visit_act = RecentActivity.last

    assert_equal [expiry_time_change_act, student_visit_act],
      group.reload.activities
  end

  def test_last_member_activity_at
    RecentActivity.destroy_all
    assert groups(:mygroup).activities.empty?
    groups(:mygroup).update_attribute :last_member_activity_at, nil
    t = nil
    Timecop.freeze(Date.today - 2.days) do
      create_scrap(:group => groups(:mygroup))
      mentor_scrap_act = RecentActivity.last
      t = Time.new.utc
      mentor_scrap_act.update_attribute :created_at, t
    end
    groups(:mygroup).reload
    assert_equal t.strftime("%B %d %Y %I:%M %p"), groups(:mygroup).last_member_activity_at.strftime("%B %d %Y %I:%M %p")

    Timecop.freeze(Date.today - 30.minutes) do
      groups(:mygroup).mark_visit(groups(:mygroup).students.first)
      visit_act = RecentActivity.last
      t = Time.new.utc
      visit_act.update_attribute :created_at, t
    end
    groups(:mygroup).reload
    assert_equal t.strftime("%B %d %Y %I:%M %p"), groups(:mygroup).last_member_activity_at.strftime("%B %d %Y %I:%M %p")
  end

  def test_member_status
    mentorship = fetch_connection_membership(:mentor, groups(:mygroup))
    studentship = fetch_connection_membership(:student, groups(:mygroup))
    assert_equal Connection::Membership::Status::ACTIVE, groups(:mygroup).member_status(users(:f_mentor))
    mentorship.status = Connection::Membership::Status::INACTIVE
    mentorship.save!
    assert_equal Connection::Membership::Status::INACTIVE, groups(:mygroup).member_status(users(:f_mentor))
  end

  def test_inactivity_in_days
    RecentActivity.destroy_all
    group = groups(:mygroup)
    mentor = group.mentors.first
    mentor_membership = group.memberships.find_by(user_id: mentor.id)
    student = group.students.first
    student_membership = group.memberships.find_by(user_id: student.id)

    group.update_attribute :created_at, 15.days.ago
    group.update_attribute :published_at, 15.days.ago
    mentor_membership.update_attribute :created_at, 5.days.ago
    student_membership.update_attribute :created_at, 5.days.ago
    assert_equal 5, group.inactivity_in_days(mentor_membership)
    assert_equal 5, group.inactivity_in_days(student_membership)

    # Make both the members inactive.
    group.set_member_status(group.membership_of(users(:f_mentor)), Connection::Membership::Status::INACTIVE)
    group.set_member_status(group.membership_of(users(:mkr_student)), Connection::Membership::Status::INACTIVE)
    group.auto_terminate_due_to_inactivity!
    assert group.reload.closed?

    assert_equal 5, group.inactivity_in_days(mentor_membership)
    assert_equal 5, group.inactivity_in_days(student_membership)

    # Now the connection's expiry date is changed.
    group.change_expiry_date(users(:f_admin), group.expiry_time + 1.month, "Hurray!")
    assert group.reload.active?

    assert_equal 0, group.inactivity_in_days(mentor_membership)
    assert_equal 0, group.inactivity_in_days(student_membership)
  end

  def test_inactivity_in_days_for_delayed_publish
    RecentActivity.destroy_all
    group = groups(:drafted_group_1)
    mentor = group.mentors.first
    mentor_membership = group.memberships.find_by(user_id: mentor.id)
    student = group.students.first
    student_membership = group.memberships.find_by(user_id: student.id)

    group.update_attribute :created_at, 15.days.ago
    mentor_membership.update_attribute :created_at, 15.days.ago
    student_membership.update_attribute :created_at, 15.days.ago
    assert_equal 15, group.inactivity_in_days(mentor_membership)
    assert_equal 15, group.inactivity_in_days(student_membership)

    group.publish(users(:f_admin), "test message")
    assert_equal 0, group.inactivity_in_days(mentor_membership)
    assert_equal 0, group.inactivity_in_days(student_membership)

    group.update_attribute :published_at, 5.days.ago
    student_membership.update_attribute :created_at, 3.days.ago
    assert_equal 5, group.inactivity_in_days(mentor_membership)
    assert_equal 3, group.inactivity_in_days(student_membership)
  end

  def test_set_member_status
    group = groups(:mygroup)
    mentor = group.mentors.first
    assert_equal Connection::Membership::Status::ACTIVE, group.member_status(mentor)

    t = 2.days.ago
    Time.expects(:now).at_least(0).returns(t)
    group.set_member_status(group.membership_of(mentor), Connection::Membership::Status::INACTIVE)
    assert_equal Connection::Membership::Status::INACTIVE, group.member_status(mentor)
    assert_equal t.strftime('%B %d %Y, %I:%M %p'),
      fetch_connection_membership(:mentor, groups(:mygroup)).reload.last_status_update_at.strftime('%B %d %Y, %I:%M %p')

    t = 5.minutes.ago
    Time.expects(:now).at_least(0).returns(t)
    group.set_member_status(group.membership_of(mentor), Connection::Membership::Status::ACTIVE)
    assert_equal Connection::Membership::Status::ACTIVE, group.member_status(mentor)
    assert_equal t.strftime('%B %d %Y, %I:%M %p'),
      fetch_connection_membership(:mentor, groups(:mygroup)).reload.last_status_update_at.strftime('%B %d %Y, %I:%M %p')
  end

  def test_track_member_statuses
    programs(:albers).update_attribute(:inactivity_tracking_period, 7.days)
    group = groups(:mygroup)
    mentor = group.mentors.first
    mentor_membership = group.memberships.find_by(user_id: mentor.id)
    student = group.students.first
    student_membership = group.memberships.find_by(user_id: student.id)

    mentorship = fetch_connection_membership(:mentor, groups(:mygroup))
    studentship = fetch_connection_membership(:student, groups(:mygroup))

    group.expects(:inactivity_in_days).at_least(0).with(mentor_membership).returns(0)
    group.expects(:inactivity_in_days).at_least(0).with(student_membership).returns(8)

    assert_emails 1 do
      group.track_member_statuses
    end

    student_email = ActionMailer::Base.deliveries.last
    assert_equal [student.email], student_email.to
    assert_equal Connection::Membership::Status::ACTIVE, mentorship.reload.status
    assert_equal Connection::Membership::Status::INACTIVE, studentship.reload.status

    group.expects(:inactivity_in_days).at_least(0).with(mentor_membership).returns(5000)
    group.expects(:inactivity_in_days).at_least(0).with(student_membership).returns(8)

    assert_emails 1 do
      group.track_member_statuses
    end

    mentor_email = ActionMailer::Base.deliveries.last
    assert_equal [mentor.email], mentor_email.to
    assert_equal Connection::Membership::Status::INACTIVE, mentorship.reload.status
    assert_equal Connection::Membership::Status::INACTIVE, studentship.reload.status

    group.memberships.reload
    assert_no_emails do
      group.track_member_statuses
    end

    assert_equal Connection::Membership::Status::INACTIVE, mentorship.reload.status
    assert_equal Connection::Membership::Status::INACTIVE, studentship.reload.status
  end

  def test_track_membership_status_for_to_be_expired_groups
    groups(:mygroup).program.update_attribute(:inactivity_tracking_period, 7.days)
    assert_equal Group::Status::ACTIVE, groups(:mygroup).status

    mentor = users(:f_mentor)
    mentor_membership = groups(:mygroup).memberships.find_by(user_id: mentor.id)
    student = users(:mkr_student)
    student_membership = groups(:mygroup).memberships.find_by(user_id: student.id)

    fetch_connection_membership(:mentor, groups(:mygroup)).update_attribute :status,
      Connection::Membership::Status::ACTIVE
    fetch_connection_membership(:student, groups(:mygroup)).update_attribute :status,
      Connection::Membership::Status::ACTIVE

    # Both members are active.
    groups(:mygroup).expects(:inactivity_in_days).at_least(0).with(mentor_membership).returns(0)
    groups(:mygroup).expects(:inactivity_in_days).at_least(0).with(student_membership).returns(8)
    groups(:mygroup).update_attribute(:expiry_time, Time.now + Connection::Membership::INACTIVITY_NOTICE_PERIOD - 1.day)

    assert_no_emails do
      groups(:mygroup).track_member_statuses
    end

    assert_equal Connection::Membership::Status::ACTIVE, fetch_connection_membership(:mentor, groups(:mygroup)).reload.status
    assert_equal Connection::Membership::Status::ACTIVE, fetch_connection_membership(:student, groups(:mygroup)).reload.status

    groups(:mygroup).expects(:inactivity_in_days).at_least(0).with(mentor_membership).returns(10)
    assert_no_emails do
      groups(:mygroup).track_member_statuses
    end
  end

  def test_create_tasks_for_added_memberships
    group = groups(:mygroup)
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    group.mentoring_model = mentoring_model
    group.save
    mentor_role = program.find_role RoleConstants::MENTOR_NAME
    student_role = program.find_role RoleConstants::STUDENT_NAME
    mentor_tt = create_mentoring_model_task_template(title: "Mentor Task", role_id: mentor_role.id, mentoring_model_id:mentoring_model.id, required: true)
    student_tt = create_mentoring_model_task_template(title: "Student Task", role_id: student_role.id, mentoring_model_id: mentoring_model.id, required: true, associated_id: mentor_tt.id)
    assert_equal 2, mentoring_model.mentoring_model_task_templates.size
    assert_equal 2, group.mentoring_model_tasks.size
    group_id = group.id
    group.memberships.create!(role_id: mentor_role.id, user_id: users(:f_admin).id)
    group.memberships.create!(role_id: student_role.id, user_id: users(:f_mentor_student).id)
    added_memberships_ids = group.memberships.where(user_id: [users(:f_admin).id, users(:f_mentor_student).id]).pluck(:id)
    assert_difference "MentoringModel::Task::count", 2 do
      Group.create_tasks_for_added_memberships(group_id, added_memberships_ids)
    end
  end

  def test_track_inactivities
    groups(:mygroup).program.update_attribute(:inactivity_tracking_period, 7.days)
    assert_equal Group::Status::ACTIVE, groups(:mygroup).reload.status

    fetch_connection_membership(:mentor, groups(:mygroup)).update_attribute :status,
      Connection::Membership::Status::ACTIVE
    fetch_connection_membership(:student, groups(:mygroup)).update_attribute :status,
      Connection::Membership::Status::ACTIVE
    Group.any_instance.expects(:track_member_statuses).at_least(0)

    # Both members are active.
    assert_no_emails do
      Group.track_inactivities
    end

    assert_equal Group::Status::ACTIVE, groups(:mygroup).reload.status
    fetch_connection_membership(:mentor, groups(:mygroup)).update_attribute :status,
      Connection::Membership::Status::INACTIVE

    assert_no_emails do
      Group.track_inactivities
    end

    assert_equal Group::Status::ACTIVE, groups(:mygroup).reload.status
    fetch_connection_membership(:student, groups(:mygroup)).update_attribute :status,
      Connection::Membership::Status::INACTIVE

    assert_false programs(:albers).auto_terminate?

    assert_no_emails do
      Group.track_inactivities
    end

    # Marked inactive.
    assert_equal Group::Status::INACTIVE, groups(:mygroup).reload.status
    programs(:albers).auto_terminate_reason_id = programs(:albers).permitted_closure_reasons.first.id
    programs(:albers).save!
    groups(:mygroup).memberships.update_all(last_status_update_at: Time.now - 16.days)

    ActionMailer::Base.deliveries.clear
    # One email per member for auto-termination.
    assert_emails 2 do
      Group.track_inactivities
    end

    # Auto terminated.
    assert groups(:mygroup).reload.auto_terminated?

    assert_equal_unordered [users(:f_mentor).email, users(:mkr_student).email],
      ActionMailer::Base.deliveries.collect(&:to).flatten

    # No email further.
    assert_no_emails do
      Group.track_inactivities
    end
  end

  ## Test should ignore malformed groups and continue with the other programs' groups
  def test_track_inactivities_with_exception_cases
    program = programs(:albers)
    program.auto_terminate_reason_id = program.permitted_closure_reasons.first.id
    program.save!
    program.reload

    groups = program.active_groups.limit(2)
    group_ids = groups.pluck(:id)
    Connection::Membership.where(group_id: group_ids).update_all(status: Connection::Membership::Status::INACTIVE)

    malformed_group = program.groups.new(mentors: groups[1].mentors, students: groups[1].students, name: "Claire and Frank")
    malformed_group.status = Group::Status::ACTIVE
    malformed_group.expiry_time = malformed_group.get_group_expiry_time

    malformed_group.save(validate: false)
    Connection::Membership.where(group_id: [malformed_group.id]).update_all(status: Connection::Membership::Status::INACTIVE)
    Connection::Membership.where(group_id: group_ids).update_all(last_status_update_at: Time.now - 16.days)
    Connection::Membership.where(group_id: [malformed_group.id]).update_all(last_status_update_at: Time.now - 16.days)

    Group.any_instance.expects(:track_member_statuses).at_least(0)
    Airbrake.expects(:notify).times(2)
    assert_emails 2 do
      Group.track_inactivities
    end

    assert_equal [Group::Status::CLOSED, Group::Status::ACTIVE, Group::Status::ACTIVE], (groups + [malformed_group]).collect(&:reload).collect(&:status)
  end

  def test_track_inactivities_for_project_based
    groups(:mygroup).update_attributes!(status: Group::Status::INACTIVE)
    assert_equal Group::Status::INACTIVE, groups(:mygroup).reload.status
    programs(:albers).auto_terminate_reason_id = programs(:albers).permitted_closure_reasons.first.id
    programs(:albers).engagement_type = Program::EngagementType::PROJECT_BASED
    programs(:albers).save!

    # One email per member for auto-termination.
    assert_no_emails do
      Group.track_inactivities
    end
  end

  def test_terminate_expired_connections
    g = groups(:mygroup)
    Timecop.travel(2.days.ago)
    g.expiry_time = 1.day.from_now
    g.save!
    Timecop.return
    assert g.active?
    assert g.expired?
    Group.terminate_expired_connections
    assert g.reload.closed?
    assert_nil g.closed_by
    assert_equal "The mentoring connection has ended", g.termination_reason
    assert_equal Group::TerminationMode::EXPIRY, g.termination_mode
  end

  def test_active_involving_users
    g = groups(:mygroup)
    mentor = users(:f_mentor)
    mentee = users(:mkr_student)
    mentee2 = users(:student_3)
    assert_equal [g], Group.active_involving_users([mentor, mentee])
    assert_equal [], Group.active_involving_users([mentor, mentee2])

    g.update_members([mentor], [mentee2])
    assert_equal [], Group.active_involving_users([mentor.reload, mentee.reload])
    assert_equal [g], Group.active_involving_users([mentor, mentee2.reload])

    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    assert_equal [], Group.active_involving_users([mentor.reload, mentee.reload])
    assert_equal [], Group.active_involving_users([mentor, mentee2.reload])
  end

  def test_auto_terminate
    g = groups(:mygroup)
    g.auto_terminate_due_to_inactivity!
    g.reload
    assert g.closed?
    assert g.auto_terminated?
    assert_nil g.closed_by
    assert_equal "The mentoring connection was closed due to inactivity", g.termination_reason
    assert_equal Group::TerminationMode::INACTIVITY, g.termination_mode
  end

  def test_remove_upcoming_meetings_of_group
    time_now = Time.now
    group = groups(:mygroup)
    meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(group.meetings, with_starttime_in: true, start_time: time_now, end_time: group.expiry_time)
    assert meetings_to_be_held.any?
    Group.remove_upcoming_meetings_of_group(group.id)
    group.reload
    meetings_to_be_held, archived_meetings = Meeting.recurrent_meetings(group.meetings, with_starttime_in: true, start_time: time_now, end_time: group.expiry_time)
    assert_empty meetings_to_be_held
  end

  def test_auto_terminated
    g = groups(:mygroup)

    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)
    assert !g.reload.auto_terminated?

    g.terminate!(nil, "The mentoring connection was closed due to inactivity", g.program.permitted_closure_reasons.first.id, Group::TerminationMode::INACTIVITY)
    assert g.reload.closed_due_to_inactivity?
    assert g.auto_terminated?

    g.terminate!(nil, "The mentoring period has ended", g.program.permitted_closure_reasons.first.id, Group::TerminationMode::EXPIRY)
    assert g.reload.closed_due_to_expiry?
    assert g.auto_terminated?
  end

  def test_auto_terminated_due_to_inactivity
    g = groups(:mygroup)
    assert !g.reload.closed_due_to_inactivity?

    g.terminate!(nil, "The mentoring connection was closed due to inactivity", g.program.permitted_closure_reasons.first.id, Group::TerminationMode::INACTIVITY)
    assert g.reload.closed_due_to_inactivity?
  end

  def test_auto_terminated_due_to_expiry
    g = groups(:mygroup)
    assert !g.reload.closed_due_to_expiry?

    g.terminate!(nil, "The mentoring period has ended", g.program.permitted_closure_reasons.first.id, Group::TerminationMode::EXPIRY)
    assert g.reload.closed_due_to_expiry?
  end

  def test_create_memberships_on_create
    allow_one_to_many_mentoring_for_program(programs(:albers))
    student_1 = users(:student_5)
    student_2 = users(:student_6)
    mentor = users(:mentor_5)

    assert_difference 'Connection::Membership.count', 3 do
      assert_difference 'Group.count' do
        @group = create_group(
          :students => [student_1, student_2],
          :mentors => [mentor],
          :program => programs(:albers))
      end
    end

    # All memberships must be active to start with.
    assert_equal [Connection::Membership::Status::ACTIVE],
      @group.memberships.collect(&:status).uniq

    assert_equal_unordered [student_1, student_2, mentor],
      @group.memberships.collect(&:user)
  end

  def test_add_or_remove_memberships_on_change
    allow_one_to_many_mentoring_for_program(programs(:albers))
    student_1 = users(:student_5)
    student_2 = users(:student_6)
    mentor = users(:mentor_5)

    assert_difference 'Connection::Membership.count', 2 do
      assert_difference 'Group.count' do
        @group = create_group(
          :students => [student_1],
          :mentors => [mentor],
          :program => programs(:albers))
      end
    end

    cache_key = mentor.reload.cache_key
    assert_difference 'Connection::Membership.count', 1 do
      assert_difference 'Connection::Membership.count', 1 do
        Timecop.freeze(5.minutes.from_now) do
          @group.update_members([mentor], [student_1, student_2])
        end
      end
    end
    assert_not_equal cache_key, mentor.reload.cache_key

    @group.created_at = 10.days.ago
    membership = Connection::Membership.last
    assert_equal student_2, membership.user
    assert_equal Connection::Membership::Status::ACTIVE, membership.status
    assert_equal 0, @group.inactivity_in_days(membership)

    assert @group.has_member?(student_1)

    assert_difference 'Connection::Membership.count', -1 do
      assert_difference 'Connection::Membership.count', -1 do
        @group.update_members([mentor], [student_2])
      end
    end

    assert_false @group.has_member?(student_1)
    role = create_role(name: "teacher", for_mentoring: true)
    user = users(:student_8)
    user.roles += [role]
    user.save!
    user.reload
    assert_difference 'Connection::Membership.count', 2 do
      assert_difference 'Connection::CustomMembership.count', 1 do
        @group.update_members([mentor], [student_1, student_2], nil, {other_roles_hash: {role => [user]}})
      end
    end
  end

  def test_delete_mentoring_model_tasks_on_removing_connection_membership
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)
    tasks = []

    5.times do |iterator|
      tasks[iterator] = create_mentoring_model_task
    end

    mentor = users(:f_mentor)
    mentor1 = users(:mentor_3)
    student_1 = users(:mkr_student)

    assert g.has_mentor?(users(:f_mentor))
    assert g.has_mentee?(users(:mkr_student))
    mentors = ([users(:mentor_3)] + g.mentors)
    students = g.students
    assert !g.has_mentor?(users(:mentor_3))

    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))

    mem1 = g.membership_of(users(:f_mentor))
    mem2 = g.membership_of(users(:mentor_3))

    assert_equal 5, mem1.mentoring_model_tasks.size
    assert_equal 0, mem2.mentoring_model_tasks.size

    # Task should be dependent nullified
    assert_difference 'Connection::Membership.count', -1 do
      assert_no_difference 'MentoringModel::Task.count' do
        g.update_members([mentor1], [student_1])
      end
    end

    5.times do |iterator|
      assert_nil tasks[iterator].user
    end
  end

  def test_update_members_should_assign_attribute_accessors
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    old_members = g.members_by_role
    mentors = ([users(:mentor_3)] + g.mentors)
    students = g.students
    assert !g.has_mentor?(users(:mentor_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))
    assert_equal old_members, g.old_members_by_role
    assert_nil g.actor

    old_members = g.members_by_role
    mentors = g.mentors
    students = ([users(:student_3)] + g.students)
    assert !g.has_mentee?(users(:student_3))
    g.update_members(mentors, students, users(:f_admin))
    g.reload
    assert g.has_mentee?(users(:student_3))
    assert_equal old_members, g.old_members_by_role
    assert_equal users(:f_admin), g.actor
  end

  def test_update_members_should_create_scrap_receivers
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    new_suspended_user = users(:mentor_3)
    new_active_user = users(:mentor_4)
    new_suspended_user.member.suspend!(members(:f_admin), "Reason")

    old_scraps_count = g.scraps.count
    old_members = g.members_by_role
    mentors = ([new_suspended_user, new_active_user] + g.mentors)
    students = g.students
    assert_false g.has_mentor?(new_suspended_user)|| g.has_mentor?(new_active_user)
    assert_equal 0, Scrap.of_member_in_ref_obj(new_active_user.member_id, g.id, Group.to_s).count
    assert_equal 0, Scrap.of_member_in_ref_obj(new_suspended_user.member_id, g.id, Group.to_s).count

    assert_difference('AbstractMessageReceiver.count', old_scraps_count) do
      g.update_members(mentors, students)
    end
    assert_equal [], g.scraps.joins(:message_receivers).where("abstract_message_receivers.message_root_id IS NULL")
    assert_equal g.reload.scraps.count, old_scraps_count
    assert_equal g.scraps.count, Scrap.of_member_in_ref_obj(new_active_user.member_id, g.id, Group.to_s).count
    assert_equal 0, Scrap.of_member_in_ref_obj(new_suspended_user.member_id, g.id, Group.to_s).count
  end

  def test_removing_users_should_remove_ra_of_members_scraps
    g = groups(:mygroup)

    mentors = ([users(:mentor_3)] + g.mentors)
    students = g.students
    assert !g.has_mentor?(users(:mentor_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))

    assert_difference('RecentActivity.count') do
      create_scrap(:group => g, :sender => members(:mentor_3))
    end
    mentors = (g.mentors - [users(:mentor_3)])
    students = g.students
    assert g.has_mentor?(users(:mentor_3))
    assert_difference('RecentActivity.count', -1) do
      assert_difference('Connection::Activity.count', -1) do
        g.update_members(mentors, students)
      end
    end
    g.reload
    assert !g.has_mentor?(users(:mentor_3))
  end

  def test_after_update_creates_tasks_for_new_members
    group = groups(:mygroup)
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.reload.default_mentoring_model
    mentor_role = program.find_role RoleConstants::MENTOR_NAME
    student_role = program.find_role RoleConstants::STUDENT_NAME
    mentor_tt = create_mentoring_model_task_template(title: "Mentor Task", role_id: mentor_role.id, mentoring_model_id: mentoring_model.id, required: true, specific_date: "2014-03-08")
    student_tt = create_mentoring_model_task_template(title: "Student Task", role_id: student_role.id, mentoring_model_id: mentoring_model.id, required: true, specific_date: "2014-03-11")
    unassigned_tt = create_mentoring_model_task_template(title: "Unassigned Task", role_id: nil, mentoring_model_id: mentoring_model.id)

    Group::MentoringModelCloner.new(group, program, mentoring_model).copy_mentoring_model_objects
    assert_equal 3, group.mentoring_model_tasks.size
    assert_equal 1, mentor_tt.mentoring_model_tasks.size

    group.update_attribute(:skip_observer, false)
    group.update_members(group.mentors + [users(:robert)], group.students)
    assert_equal 4, group.mentoring_model_tasks.size
    assert_equal 2, mentor_tt.mentoring_model_tasks.size
  end

  def test_create_ra_and_notify_mentee_about_mentoring_offer
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)
    mentor = g.mentors.first
    mentee = g.students.first
    new_mentee = users(:f_student)

    assert !g.has_mentee?(new_mentee)
    g.update_members([mentor], [mentee, new_mentee])
    assert g.reload.has_mentee?(new_mentee)

    g.actor = mentor
    g.offered_to = new_mentee
    assert_pending_notifications do
      assert_difference('Connection::Activity.count', 1) do
        assert_difference('RecentActivity.count', 1) do
          assert_difference('ActionMailer::Base.deliveries.size', 1) do
            g.create_ra_and_notify_mentee_about_mentoring_offer
            g.notify_group_members_about_member_update
          end
        end
      end
    end

    ra = RecentActivity.last
    assert_equal g, ra.ref_obj
    assert_equal RecentActivityConstants::Type::MENTORING_OFFER_DIRECT_ADDITION, ra.action_type
    assert_equal [g.program], ra.programs
    assert_equal mentor, ra.get_user(programs(:albers))
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_equal new_mentee.id.to_s, ra.message

    email = ActionMailer::Base.deliveries[-1]
    assert_equal new_mentee.email, email.to[0]
    assert_match(/You have a new mentor!/, email.subject)

    notif = PendingNotification.last
    assert_equal notif.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal notif.ref_obj_creator.user, mentee
  end

  def test_create_ra_and_notify_members_about_member_update
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    old_members_by_role = g.members_by_role
    mentors = ([users(:mentor_3)] + g.mentors)
    students = ([users(:student_3)] + g.students)
    assert !g.has_mentor?(users(:mentor_3))
    assert !g.has_mentee?(users(:student_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))
    assert g.has_mentee?(users(:student_3))

    Push::Base.expects(:queued_notify).times(2)
    assert_pending_notifications 2 do
      assert_difference('RecentActivity.count', 2) do
        assert_emails 2 do
          assert_no_difference "JobLog.count" do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role)
          end
        end
      end
    end

    ra = RecentActivity.last
    assert_equal g, ra.ref_obj
    assert_equal RecentActivityConstants::Type::GROUP_MEMBER_ADDITION, ra.action_type
    assert_equal [g.program], ra.programs
    assert_equal users(:student_3), ra.get_user(programs(:albers))
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_nil ra.message

    email = ActionMailer::Base.deliveries[-2]
    assert_equal users(:mentor_3).email, email.to[0]
    assert_match(/You have been added as a mentor to name & madankumarrajan/, email.subject)

    email = ActionMailer::Base.deliveries[-1]
    assert_equal users(:student_3).email, email.to[0]
    assert_match(/You have been added as a student to name & madankumarrajan/, email.subject)

    notif_1 = PendingNotification.all[-1]
    assert_equal notif_1.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal notif_1.ref_obj_creator.user, users(:f_mentor)

    notif_2 = PendingNotification.all[-2]
    assert_equal notif_2.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal notif_2.ref_obj_creator.user, users(:mkr_student)

    old_members_by_role = g.members_by_role
    g.update_members([users(:f_mentor)], [users(:mkr_student)] + [users(:student_3)])
    g.reload
    assert_false g.has_mentor?(users(:mentor_3))
    assert g.has_mentee?(users(:student_3))

    Push::Base.expects(:queued_notify).never
    assert_pending_notifications 3 do
      assert_difference('RecentActivity.count', 1) do
        assert_difference('ActionMailer::Base.deliveries.size') do
          assert_no_difference "JobLog.count" do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role)
          end
        end
      end
    end

    ra = RecentActivity.last
    assert_equal g, ra.ref_obj
    assert_equal RecentActivityConstants::Type::GROUP_MEMBER_REMOVAL, ra.action_type
    assert_equal [g.program], ra.programs
    assert_equal users(:mentor_3), ra.get_user(programs(:albers))
    assert_equal RecentActivityConstants::Target::ALL, ra.target
    assert_nil ra.message

    email = ActionMailer::Base.deliveries[-1]
    assert_equal users(:mentor_3).email, email.to[0]
    assert_match(/You have been removed from name & madankumarrajan by the program administrator/, email.subject)

    notif_1 = PendingNotification.all[-1]
    assert_equal notif_1.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal notif_1.ref_obj_creator.user, users(:student_3)

    notif_2 = PendingNotification.all[-2]
    assert_equal notif_2.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal notif_2.ref_obj_creator.user, users(:f_mentor)

    notif_3 = PendingNotification.all[-3]
    assert_equal notif_3.action_type, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    assert_equal notif_3.ref_obj_creator.user, users(:mkr_student)

    Push::Base.expects(:queued_notify).never
    assert_pending_notifications 3 do
      assert_difference('RecentActivity.count', 1) do
        assert_difference('ActionMailer::Base.deliveries.size') do
          assert_no_difference "JobLog.count" do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role)
          end
        end
      end
    end
  end

  def test_create_ra_and_notify_members_about_member_update_with_job_uuid
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    old_members_by_role = g.members_by_role
    mentors = ([users(:mentor_3)] + g.mentors)
    students = ([users(:student_3)] + g.students)
    assert !g.has_mentor?(users(:mentor_3))
    assert !g.has_mentee?(users(:student_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))
    assert g.has_mentee?(users(:student_3))

    Push::Base.expects(:queued_notify).times(2)
    assert_pending_notifications 2 do
      assert_difference('RecentActivity.count', 2) do
        assert_emails 2 do
          assert_difference "JobLog.count", 4 do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role, "15")
          end
        end
      end
    end

    Push::Base.expects(:queued_notify).never
    assert_pending_notifications 0 do
      assert_no_difference 'RecentActivity.count' do
        assert_no_difference "JobLog.count" do
          assert_no_emails do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role, "15")
          end
        end
      end
    end

    # Remove and add users
    old_members_by_role = g.members_by_role
    mentors = ([users(:mentor_4)] + g.mentors)
    students = g.students - [users(:student_3)]
    g.update_members(mentors, students)
    g.reload

    Push::Base.expects(:queued_notify).once
    assert_pending_notifications 3 do
      assert_difference 'RecentActivity.count', 2 do
        assert_difference("JobLog.count", 5) do
          assert_emails 2 do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role, "16")
          end
        end
      end
    end

    Push::Base.expects(:queued_notify).never
    assert_pending_notifications 0 do
      assert_no_difference 'RecentActivity.count' do
        assert_no_difference("JobLog.count") do
          assert_no_emails do
            Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role, "16")
          end
        end
      end
    end
  end

  def test_update_members_nullify_bulk_match_id
    group = groups(:mygroup)
    bulk_match = group.program.bulk_matches.first
    group.update_attribute(:bulk_match, bulk_match)
    existing_students = group.students
    existing_mentors = group.mentors

    assert_equal true, group.update_members(existing_mentors + [users(:mentor_3)], existing_students + [users(:f_student)])
    assert_equal bulk_match, group.reload.bulk_match

    # When atleast one user of the initial pair is removed from the connection, it's dissociated from bulk_match
    assert_equal true, group.update_members([users(:mentor_3)], existing_students + [users(:f_student)])
    assert_nil group.reload.bulk_match
  end

  def test_mentor_accessors
    assert groups(:mygroup).has_member?(users(:f_mentor))
    assert !groups(:mygroup).has_member?(users(:mentor_3))

    assert_no_difference 'Connection::Membership.count' do
      groups(:mygroup).mentors = [users(:mentor_3)]
      groups(:mygroup).save!
    end

    groups(:mygroup).reload
    assert !groups(:mygroup).has_member?(users(:f_mentor))
    assert groups(:mygroup).has_member?(users(:mentor_3))
  end

  def test_student_accessors
    allow_one_to_many_mentoring_for_program(programs(:albers))

    assert groups(:mygroup).has_member?(users(:mkr_student))
    assert !groups(:mygroup).has_member?(users(:student_3))

    assert_difference 'Connection::Membership.count' do
      groups(:mygroup).students = [users(:mkr_student), users(:student_3)]
      groups(:mygroup).save!
    end

    groups(:mygroup).students.reload
    assert groups(:mygroup).has_member?(users(:mkr_student))
    assert groups(:mygroup).has_member?(users(:student_3))

    assert_difference 'Connection::Membership.count', -1 do
      groups(:mygroup).students = [users(:student_3)]
      groups(:mygroup).save!
    end

    groups(:mygroup).reload
    assert !groups(:mygroup).has_member?(users(:mkr_student))
    assert groups(:mygroup).has_member?(users(:student_3))
  end

  def test_check_only_one_group_for_a_student_mentor_pair
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    students = [users(:student_3), users(:student_5)]
    mentor = users(:mentor_3)
    mentor.update_attribute(:max_connections_limit, 3)

    # Allow multiple groups set to false; only active groups between pair
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(false)
    assert_difference "Group.count" do
      @group = create_group(students: students, mentors: [mentor])
    end
    group_2 = program.groups.new(students: [students[1].reload], mentors: [mentor.reload])
    assert_false group_2.valid?
    assert group_2.errors[:base].include? "#{mentor.name} is already a mentor to #{students[1].name}"

    # Allow multiple groups set to true; mentor's limit is reached; only active groups between pair
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(true)
    group_2 = program.groups.new(students: students.map(&:reload), mentors: [mentor.reload])
    assert_false group_2.valid?
    assert group_2.errors[:base].include? "#{mentor.name} preferred not to have more than 3 students"

    # Allow multiple groups set to true; mentor's limit is not reached; only active groups between pair
    mentor.update_attribute(:max_connections_limit, 10)
    assert_difference "Group.count" do
      @group_2 = create_group(students: [students[1].reload], mentors: [mentor.reload])
    end

    # Allow multiple groups set to false; only active groups between pair
    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(false)
    assert_false @group_2.valid?

    # Allow multiple groups set to false; only closed groups between pair
    @group.auto_terminate_due_to_inactivity!
    assert @group.closed?
    assert @group_2.valid?
  end

  def test_drafted_check_only_one_group_for_a_student_mentor_pair
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    students = [users(:student_3), users(:student_5)]
    mentor = users(:mentor_3)
    mentor.update_attribute(:max_connections_limit, 3)

    Program.any_instance.stubs(:allow_multiple_groups_between_student_mentor_pair?).returns(false)
    assert_difference "Group.count" do
      @group = create_group(students: students, mentors: [mentor], status: Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    end
    group_2 = program.groups.new(students: [students[1].reload], mentors: [mentor.reload])
    assert_false group_2.valid?
    assert group_2.errors[:base].include? "#{students[1].name} is already drafted with #{mentor.name}. Please select a different mentor."
  end

  def test_check_closed_by_is_admin_or_auto_termination_validation
    g = groups(:mygroup)
    g.status = Group::Status::INACTIVE
    assert_nothing_raised  do
      g.save!
    end
    check_group_state_change_unit(g, GroupStateChange.last, Group::Status::ACTIVE)

    g.reload

    assert_nothing_raised do
      g.auto_terminate_due_to_inactivity!
    end

    assert_equal Group::Status::CLOSED, g.reload.status
    check_group_state_change_unit(g, GroupStateChange.last, Group::Status::INACTIVE)

    assert_nothing_raised do
      g.change_expiry_date(users(:f_admin), g.expiry_time + 2.months, "Peace")
    end

    assert_equal Group::Status::ACTIVE, g.reload.status

    e = assert_raise(ActiveRecord::RecordInvalid) do
      g.terminate!(users(:f_mentor), "sorry", g.program.permitted_closure_reasons.first.id)
    end

    assert_match /The user is not authorized to terminate the mentoring connection/, e.message
    assert_equal Group::Status::ACTIVE, g.reload.status

    assert_nothing_raised do
      g.terminate!(users(:f_admin), "sorry", g.program.permitted_closure_reasons.first.id)
    end

    assert_equal Group::Status::CLOSED, g.reload.status
    check_group_state_change_unit(g, GroupStateChange.last, Group::Status::ACTIVE)
    assert_equal 5, g.state_changes.count
  end

  def test_should_generate_pdf_report
    mentor = groups(:mygroup).mentors.first

    MentoringAreaExporter.expects(:generate_pdf).with(mentor, groups(:mygroup), false, false).returns("Test pdf content").times(2)

    assert_emails(1) do
      assert_no_difference "JobLog.count" do
        groups(:mygroup).generate_and_email_mentoring_area(mentor)
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.pdf/, email.attachments.first.filename)

    assert_emails(1) do
      assert_no_difference "JobLog.count" do
        groups(:mygroup).generate_and_email_mentoring_area(mentor)
      end
    end
  end

  def test_generate_report_with_job_uuid
    mentor = groups(:mygroup).mentors.first

    MentoringAreaExporter.expects(:generate_pdf).with(mentor, groups(:mygroup), false, false).returns("Test pdf content")

    assert_emails(1) do
      assert_difference "JobLog.count" do
        groups(:mygroup).generate_and_email_mentoring_area(mentor, "15")
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        groups(:mygroup).generate_and_email_mentoring_area(mentor, "15")
      end
    end
  end

  def test_should_generate_pdf_report_with_remote_images
    group = groups(:mygroup)
    mentor = group.mentors.first

    ImportExportUtils.expects(:file_url).times(2).returns("https://chronus-mentor-assets.s3.amazonaws.com/global-assets/images/user_small.jpg")
    assert_emails do
      group.generate_and_email_mentoring_area(mentor)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal [mentor.email], email.to
    assert_equal "Exported PDF file for #{group.name}", email.subject
    assert_match(/Mentoring Connection-.+\.pdf/, email.attachments.first.filename)
  end

  def test_should_generate_zip_report
    student = groups(:mygroup).students[0]
    create_scrap(:group => groups(:mygroup), :attachment => fixture_file_upload(File.join('files', 'test_file.css'), 'text/css'))

    MentoringAreaExporter.expects(:generate_zip).returns("Test zip content")

    assert_emails(1) do
      groups(:mygroup).generate_and_email_mentoring_area(student)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([student.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.zip/, email.attachments.first.filename)
  end

  def test_should_generate_pdf_report_for_admin
    admin = users(:f_admin)
    MentoringAreaExporter.expects(:generate_pdf).with(admin, groups(:mygroup), true).returns("Test pdf content")

    assert_emails(1) do
      groups(:mygroup).generate_and_email_mentoring_area(admin)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.pdf/, email.attachments.first.filename)
  end

  def test_membership_of
    assert_equal fetch_connection_membership(:mentor, groups(:mygroup)),
      groups(:mygroup).membership_of(users(:f_mentor))
    assert_equal fetch_connection_membership(:student, groups(:mygroup)),
      groups(:mygroup).membership_of(users(:mkr_student))
    assert_nil groups(:mygroup).membership_of(users(:student_3))
    assert_equal fetch_connection_membership(:mentor, Group.all[1]),
      groups(:group_2).membership_of(users(:not_requestable_mentor))
    assert_nil groups(:mygroup).membership_of(users(:not_requestable_mentor))
  end

  def test_should_generate_pdf_report
    mentor = groups(:mygroup).mentors.first

    MentoringAreaExporter.expects(:generate_pdf).with(mentor, groups(:mygroup), false, false).returns("Test pdf content")

    assert_emails(1) do
      groups(:mygroup).generate_and_email_mentoring_area(mentor)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([mentor.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.pdf/, email.attachments.first.filename)
  end

  def test_should_generate_zip_report_with_scraps
    student = groups(:mygroup).students[0]
    create_scrap(:group => groups(:mygroup), :attachment => fixture_file_upload(File.join('files', 'test_file.css'), 'text/css'))

    MentoringAreaExporter.expects(:generate_zip).returns("Test zip content")

    assert_emails(1) do
      groups(:mygroup).generate_and_email_mentoring_area(student)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([student.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.zip/, email.attachments.first.filename)
  end

  def test_should_generate_zip_report_with_private_notes
    student = groups(:mygroup).students[0]
    Connection::PrivateNote.create!(
      :connection_membership => fetch_connection_membership(:student, groups(:mygroup)),
      :text => "Hey, my note!",
      :attachment => fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')
    )

    MentoringAreaExporter.expects(:generate_zip).returns("Test zip content")

    assert_emails(1) do
      groups(:mygroup).generate_and_email_mentoring_area(student)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([student.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.zip/, email.attachments.first.filename)
  end

  def test_should_generate_pdf_report_for_admin
    admin = users(:f_admin)
    MentoringAreaExporter.expects(:generate_pdf).with(admin, groups(:mygroup), true, false).returns("Test pdf content")

    assert_emails(1) do
      groups(:mygroup).generate_and_email_mentoring_area(admin)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal([admin.email], email.to)
    assert_equal("Exported PDF file for name & madankumarrajan", email.subject)
    assert_match(/Mentoring Connection-.+\.pdf/, email.attachments.first.filename)
  end

  def test_single_mentee
    g1 = groups(:group_4)
    assert_equal(1, g1.students.size)
    assert(g1.single_mentee?)

    g2 = groups(:multi_group)
    assert_equal(3, g2.students.size)
    assert(!g2.single_mentee?)
  end

  def test_last_activated_at
    g = groups(:mygroup)
    assert_nil g.last_activated_at

    g.terminate!(users(:f_admin), "some reason", g.program.permitted_closure_reasons.first.id)
    assert g.reload.closed?

    Timecop.freeze(Time.now) do
      g.change_expiry_date(users(:ram), g.expiry_time + 4.months, "Peace")
      assert g.reload.active?
      t1 = Time.now.utc
      assert_equal t1.strftime("%d %b %y %I:%M %p"), g.last_activated_at.strftime("%d %b %y %I:%M %p")
    end

    g.terminate!(users(:f_admin), "some reason", g.program.permitted_closure_reasons.first.id)
    assert g.reload.closed?

    Timecop.freeze(Time.now + 2.months) do
      g.change_expiry_date(users(:ram), g.expiry_time + 4.months, "Peace")
      assert g.reload.active?
      t2 = Time.now.utc
      assert_equal t2.strftime("%d %b %y %I:%M %p"), g.last_activated_at.strftime("%d %b %y %I:%M %p")
    end
  end

  def test_answer_for_question
    org_q = common_questions(:string_connection_q)
    g1 = Group.find(1)
    g2 = Group.find(2)

    assert_equal common_answers(:one_connection), g1.answer_for(org_q)
    a1 = Connection::Answer.create!(:group => g2, :question => org_q, :answer_text => "Whatever")
    assert_equal a1, g2.answer_for(org_q)
  end

  def test_update_answers
    map = {
      common_questions(:string_connection_q).id.to_s => "hello",
      common_questions(:single_choice_connection_q).id.to_s => "opt_2",
      common_questions(:multi_choice_connection_q).id.to_s => ["Walk","Run"],
    }

    assert_difference "Connection::Answer.count", 3 do
      assert groups(:group_2).update_answers(map)
    end

  end

  def test_update_answers_with_from_import
    map = {
      common_questions(:string_connection_q).id.to_s => "hello2",
      common_questions(:single_choice_connection_q).id.to_s => "opt_1",
      common_questions(:multi_choice_connection_q).id.to_s => "Stand,Run",
    }

    assert_difference "Connection::Answer.count", 3 do
      assert groups(:group_2).update_answers(map, true)
    end
  end

  def test_update_answers_failure
    stub_paperclip_size(21.megabytes.to_i)
    group = groups(:group_2)

    q = Connection::Question.create!(:program => programs(:albers), :question_text => "File", :question_type => CommonQuestion::Type::FILE)
    assert_no_difference "Connection::Answer.count" do
      assert_false group.update_answers("#{q.id}" => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end

    assert group.errors[:answers]
  end

  def test_logo_url
    group = groups(:mygroup)
    assert_false group.logo?
    assert_equal GroupConstants::DEFAULT_LOGO, group.logo_url
    group.logo = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    group.save!

    assert group.logo?
    assert_equal group.logo.url, group.logo_url
  end

  def test_group_terminate
    g = groups(:mygroup)
    user = users(:f_mentor)
    mentor_memberships = g.mentor_memberships
    student_memberships = g.student_memberships
    assert_equal 2, g.memberships.size
    assert_equal (mentor_memberships.where(:user_id =>user.id).size == 1 && mentor_memberships.size == 1) ||
        (student_memberships.where(:user_id =>user.id).size == 1 && student_memberships.size == 1) , true
  end

  def test_get_mentoring_locations
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    men = create_mentoring_slot(:member => members(:f_mentor), :location => "Indore")
    assert_equal members(:f_mentor).mentoring_slots.last, men
    men1 = create_mentoring_slot(:member => members(:f_mentor), :location => "")
    assert_equal members(:f_mentor).mentoring_slots.last, men1
    men2 = create_mentoring_slot(:member => members(:f_mentor))
    assert_equal members(:f_mentor).mentoring_slots.last, men2
    users(:mkr_student).promote_to_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
    men3 = create_mentoring_slot(:member => members(:mkr_student), :location => "Chennai")
    assert_equal members(:mkr_student).mentoring_slots.last, men3
    assert_equal groups(:mygroup).get_mentoring_locations(programs(:org_primary)), ["Bhopal", "Indore", "Chennai"]
  end

  def test_available_roles_for_joining
    group = groups(:group_pbe_1)
    program = programs(:pbe)
    user = users(:f_student_pbe)
    user.add_role("teacher")
    user.reload
    teacher_role = program.roles.find_by(name: "teacher")
    student_role = program.roles.find_by(name: "student")

    teacher_role.add_permission(RolePermission::SEND_PROJECT_REQUEST)
    assert_equal ["student", "teacher"], group.available_roles_for_joining(user.role_ids).collect(&:name)

    groups(:group_pbe_1).membership_settings.create!(role_id: student_role.id, max_limit: 2)
    assert_equal ["student", "teacher"], group.reload.available_roles_for_joining(user.role_ids, dont_consider_slots: true).collect(&:name)
    assert_equal ["teacher"], group.reload.available_roles_for_joining(user.role_ids).collect(&:name)

    groups(:group_pbe_1).membership_settings.destroy_all
    groups(:group_pbe_1).membership_settings.create!(role_id: teacher_role.id, max_limit: 1)
    assert_equal ["student", "teacher"], group.reload.available_roles_for_joining(user.role_ids).collect(&:name)

    group.students = []
    group.custom_memberships.create!(role_id: teacher_role.id, user_id: users(:f_student_pbe).id)
    assert_equal ["student"], group.reload.available_roles_for_joining(user.role_ids).collect(&:name)

    # Disallow_join at group level
    group.program.mentoring_role_ids.each { |role_id| group.membership_settings.find_or_create_by(role_id: role_id, allow_join: false) }
    assert_equal [], group.available_roles_for_joining(user.role_ids)
  end

  def test_belongs_to_bulk_match
    bulk_match = bulk_matches(:bulk_match_1)
    group = groups(:mygroup)
    group.bulk_match = bulk_match
    group.save!

    assert_equal bulk_match, group.bulk_match
    bulk_match.destroy
    assert_nil group.reload.bulk_match
  end

  def test_scope_with_student_ids
    program = programs(:albers)
    group = groups(:mygroup)
    assert_equal [group], program.groups.with_student_ids(group.students.collect(&:id))
  end

  def test_order_desc_of_coaching_goals
    group = groups(:group_2)

    cg1 = nil
    time_traveller(2.days.ago) do
      cg1 = create_coaching_goal({:title => "First goal", :group_id => group.id})
    end

    cg2 = nil
    time_traveller(1.days.ago) do
      cg2 = create_coaching_goal({:title => "Second goal", :group_id => group.id})
    end

    assert_equal [cg2, cg1], group.coaching_goals
  end

  def test_has_many_meetings
    group = groups(:mygroup)
    assert group.meetings.present?

    meeting = group.meetings.last
    meeting.update_attributes!(active: false)

    assert_false group.meetings.reload.include?(meeting)
  end

  def test_add_mentors
    group = groups(:mygroup)

    assert_equal [users(:f_mentor)], group.mentors
    assert_equal [users(:mkr_student)], group.students

    user = users(:f_mentor)
    user.update_attributes!(:max_connections_limit => 2)
    group.reload

    assert group.update_members(group.mentors, [users(:mkr_student), users(:student_1)])

    assert group.valid?
    assert_equal [users(:mkr_student), users(:student_1)], group.reload.students

    new_mentor = users(:ram)
    new_mentor.update_attributes!(:max_connections_limit => 1)
    new_mentor.reload

    assert_false group.update_members([users(:f_mentor) , new_mentor], group.students)

    assert_equal ["Kal Raman (Administrator) preferred not to have more than 1 students"], group.errors[:base]
    assert_equal [users(:f_mentor)], group.reload.mentors
  end

  def test_add_students
    group = groups(:mygroup)

    assert_equal [users(:f_mentor)], group.mentors
    assert_equal [users(:mkr_student)], group.students

    user = users(:f_mentor)
    user.update_attributes!(:max_connections_limit => 1)
    group.reload

    assert_false group.update_members(group.mentors, [users(:mkr_student), users(:student_1)])

    assert_equal ["Good unique name preferred not to have more than 1 students"], group.errors[:base]
    assert_equal [users(:mkr_student)], group.reload.students
  end

  def test_new_connection_after_limit_reached
    user = users(:f_mentor)
    user.update_attributes!(:max_connections_limit => 1)
    user.reload
    assert_equal 1, user.groups.size

    assert_no_difference 'Group.active.size' do
      assert_raise ActiveRecord::RecordInvalid do
        new_group = create_group(
          :program => programs(:albers),
          :students => [users(:f_student)],
          :mentors => [users(:f_mentor)]
        )
      end
    end

    assert_equal 1, user.groups.reload.size
  end

  def test_drafted_to_publish
    user = users(:f_mentor)
    user.update_attributes!(:max_connections_limit => 2)
    user.reload

    assert_equal 1, user.groups.size

    test_group = create_group(
      :program => programs(:albers),
      :students => [users(:f_student)],
      :mentors => [users(:f_mentor)],
      :actor => users(:f_admin)
    )
    test_group.status = Group::Status::DRAFTED
    test_group.created_by = users(:f_admin)
    test_group.save!

    assert_equal 2, user.groups.reload.size
    assert_equal 1, user.groups.reload.active.size

    user.update_attribute(:max_connections_limit, 1)
    user.reload

    assert_no_difference 'Group.active.size' do
      assert_raise ActiveRecord::RecordInvalid do
        test_group.reload.publish(users(:f_admin), "test message")
      end
    end
    assert_equal 2, user.groups.reload.size
    assert_equal 1, user.groups.reload.active.size
  end

  def test_closed_to_publish
    group = groups(:group_4)
    user = users(:requestable_mentor)
    user.update_attributes!(max_connections_limit: 1)
    user.reload

    new_group = create_group(
      :program => programs(:albers),
      :students => [users(:f_student)],
      :mentors => [user]
    )
    new_group.save!

    assert_equal 1, user.groups.reload.active.size
    group.change_expiry_date(:f_admin, group.expiry_time+6.months ,"testing")
    assert !group.valid?
    assert_equal 1, user.groups.reload.active.size
  end

  def test_publish_with_allow_join
    group = groups(:group_pbe_0)
    actor = users(:f_admin)
    group.publish(actor, "test message", false)
    assert group.published?
    assert_false group.membership_settings.pluck(:allow_join).any?
  end

  def test_activity_count
    group = groups(:mygroup)
    assert_equal 0, group.connection_activities.size
    assert Group.get_filtered_groups(:must_filters => {:program_id => programs(:albers).id, :activity_count => 0}).to_a.include?(group)
    assert_false Group.get_filtered_groups(:must_filters => {:program_id => programs(:albers).id, :activity_count => 1}).to_a.include?(group)
  end

  def test_copy_object_role_permissions_from
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    roles = program.roles.for_mentoring_models.all

    mentoring_model.allow_manage_mm_tasks!(roles)
    mentoring_model.deny_manage_mm_goals!(roles)

    group = program.groups.first

    group.deny_manage_mm_tasks!(roles)
    group.allow_manage_mm_goals!(roles)

    assert_false group.reload.can_manage_mm_tasks?(roles)
    assert group.reload.can_manage_mm_goals?(roles)

    mentoring_model_cloner = Group::MentoringModelCloner.new(group, program, program.default_mentoring_model)
    mentoring_model_cloner.copy_permissions

    assert group.reload.can_manage_mm_tasks?(roles)
    assert_false group.reload.can_manage_mm_goals?(roles)
  end

  def test_update_members_adds_to_delayed_job
    group = groups(:mygroup)

    assert_equal [users(:f_mentor)], group.mentors
    assert_equal [users(:mkr_student)], group.students

    Connection::Membership.expects(:delay).returns(Connection::Membership).once
    assert group.update_members([users(:ram)], [users(:student_1)])
    assert_equal [users(:ram)], group.reload.mentors
    assert_equal [users(:student_1)], group.students
  end

  def test_mentoring_model_milestones
    group = groups(:mygroup)

    m1 = create_mentoring_model_milestone({group_id: group.id, title: "milestone1"})
    m2 = create_mentoring_model_milestone({group_id: group.id, title: "milestone2"})
    m3 = create_mentoring_model_milestone({group_id: group.id, title: "milestone3"})

    m1.update_attribute(:position, 3)
    m2.update_attribute(:position, 1)
    m3.update_attribute(:position, 2)

    assert_equal ["milestone2", "milestone3", "milestone1"], group.reload.mentoring_model_milestones.map(&:title)

    assert_equal 3, group.mentoring_model_milestones.size

    assert_difference "MentoringModel::Milestone.count", -3 do
      group.destroy
    end
  end

  def test_set_milestones_positions
    group = groups(:mygroup)
    group.update_attribute(:mentoring_model_id, group.program.default_mentoring_model.id)

    mt1 = create_mentoring_model_milestone_template(title: "Template1")
    mt2 = create_mentoring_model_milestone_template(title: "Template2")
    mt3 = create_mentoring_model_milestone_template(title: "Template3")
    mt4 = create_mentoring_model_milestone_template(title: "Template4")
    cmt = create_mentoring_model_milestone(group_id: group.id, title: "Custom Milestone")

    group.mentoring_model.reload
    assert_equal 5, group.reload.mentoring_model_milestones.size
    assert_equal ["Template1", "Template2", "Template3", "Template4", "Custom Milestone"], group.mentoring_model_milestones.map(&:title)

    cmt.update_attribute(:position, -1)
    assert_equal ["Custom Milestone", "Template1", "Template2", "Template3", "Template4"], group.reload.mentoring_model_milestones.map(&:title)

    mt2.update_attribute(:position, 2)
    mt3.update_attribute(:position, 1)
    group.reload.set_milestones_positions
    assert_equal ["Template1", "Template3", "Template2", "Template4", "Custom Milestone"], group.reload.mentoring_model_milestones.map(&:title)
  end

  def test_get_position_for_new_milestone
    group = groups(:mygroup)
    group.update_attribute(:mentoring_model_id, group.program.default_mentoring_model.id)

    group.mentoring_model_milestones.destroy_all

    assert_equal 0, group.reload.get_position_for_new_milestone

    cmt1 = create_mentoring_model_milestone
    cmt1.update_attribute(:position, nil)
    assert_equal 1, group.reload.get_position_for_new_milestone

    cmt1.update_attribute(:position, 0)
    cmt2 = create_mentoring_model_milestone

    assert_equal 2, group.reload.get_position_for_new_milestone

    MentoringModel.any_instance.stubs(:hybrid?).returns(true)
    assert_nil group.get_position_for_new_milestone

    MentoringModel.any_instance.unstub(:hybrid?)
    assert_equal 2, group.reload.get_position_for_new_milestone

    group.update_attribute(:mentoring_model_id, nil)
    assert_nil group.get_position_for_new_milestone
  end

  def test_mentoring_model_id_with_option
    mentoring_model = programs(:albers).default_mentoring_model
    assert Group.get_filtered_groups(must_filters: { mentoring_model_id: [mentoring_model.id] }).to_a.empty?
  end

  def test_posts_activity
    group = groups(:multi_group)
    mentor1 = group.mentors.first
    mentor2 = group.mentors.second
    student = group.students.first
    program = group.program
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    group.stubs(:forum_enabled?).returns true

    group.create_group_forum
    topic1 = create_topic(forum: group.forum, user: mentor1)
    topic2 = create_topic(forum: group.forum, user: mentor1)

    create_post(topic: topic1, user: student)
    create_post(topic: topic1, user: mentor1)
    create_post(topic: topic2, user: student)
    create_post(topic: topic2, user: mentor2)
    create_post(topic: topic2, user: student)

    assert_equal 5, group.posts_activity(nil, false)
    assert_equal 2, group.posts_activity(mentor_role_id, false)
    assert_equal 3, group.posts_activity(student_role_id, false)
    assert_equal 1, group.posts_activity[mentor1.id]
    assert_equal 3, group.posts_activity[student.id]

    group.update_members(group.mentors, group.students - [student])
    assert_equal 5, group.posts_activity(nil, false)
    assert_equal 2, group.posts_activity(mentor_role_id, false)
    assert_equal 0, group.posts_activity(student_role_id, false)

    group.update_members(group.mentors, group.students + [student])
    time_traveller(1.day.from_now) do
      create_post(topic: topic1, user: mentor2)
      create_post(topic: topic1, user: student)
    end
    time_traveller(2.days.ago) do
      create_post(topic: topic2, user: mentor1)
    end
    assert_equal 3, group.posts_activity(student_role_id, false, {:start_time => program.created_at, :end_time => Time.now.utc})
    assert_equal 1, group.posts_activity(student_role_id, false, {:start_time => 1.hour.from_now, :end_time => 2.days.from_now})
    assert_equal 1, group.posts_activity(mentor_role_id, false, {:start_time => 1.hour.from_now, :end_time => 2.days.from_now})
    assert_equal 4, group.posts_activity(mentor_role_id, false, {:start_time => program.created_at, :end_time => 2.days.from_now})
  end

  def test_scraps_activity
    program = programs(:albers)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    group = groups(:mygroup)
    new_user = users(:f_student)

    group.update_members(group.mentors, group.students + [new_user])
    create_scrap(:group => group, :sender => new_user.member)

    assert_equal 7, group.scraps_activity(nil, false)
    assert_equal 4, group.scraps_activity(mentor_role_id, false)
    assert_equal 3, group.scraps_activity(student_role_id, false)
    assert_equal 4, group.scraps_activity[members(:f_mentor).id]
    assert_equal 2, group.scraps_activity[members(:mkr_student).id]

    group.update_members(group.mentors, group.students - [new_user])
    assert_equal 7, group.scraps_activity(nil, false)
    assert_equal 4, group.scraps_activity(mentor_role_id, false)
    assert_equal 2, group.scraps_activity(student_role_id, false)

    group.update_members(group.mentors, group.students + [group.students.first])
    time_traveller(1.day.from_now) do
      create_scrap(:group => group, :sender => members(:f_mentor))
    end
    time_traveller(2.days.ago) do
      create_scrap(:group => group, :sender => members(:mkr_student))
    end
    assert_equal 3, group.scraps_activity(student_role_id, false, {:start_time => program.created_at, :end_time => Time.now.utc})
    assert_equal 1, group.scraps_activity(mentor_role_id, false, {:start_time => Time.now.utc, :end_time => 2.days.from_now})
    assert_equal 5, group.scraps_activity(mentor_role_id, false, {:start_time => program.created_at, :end_time => 2.days.from_now})
  end

  def test_login_activity
    time = Time.now
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    student = users(:f_student)
    student2 = users(:f_mentor_student)
    mentor = users(:f_mentor)
    mentor.update_attribute(:max_connections_limit, 5)

    # Group creation
    group = create_group(:students => [student,student2], :mentor => mentor, :program => program)
    # Membership creation
    student_connection_membership = student.connection_memberships.where(:group_id => group.id).first
    student2_connection_membership = student2.connection_memberships.where(:group_id => group.id).first
    mentor_connection_membership = mentor.connection_memberships.where(:group_id => group.id).first
    student_connection_membership.update_column(:login_count, 2)
    student2_connection_membership.update_column(:login_count, 1)
    mentor_connection_membership.update_column(:login_count, 5)
    # detailed view
    assert_equal student_connection_membership.login_count, group.login_activity[student.id]
    assert_equal mentor_connection_membership.login_count, group.login_activity[mentor.id]
    # table view
    assert_equal 8, group.login_activity(false)
  end

  def test_meetings_activity
    time = Time.now
    program = programs(:albers)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    allow_one_to_many_mentoring_for_program(program)
    student = users(:f_student)
    student2 = users(:f_mentor_student)
    student3 = users(:rahim)
    mentor = users(:f_mentor)
    mentor2 = users(:ram)
    users(:f_mentor).update_attribute(:max_connections_limit, 4)
    users(:ram).update_attribute(:max_connections_limit, 4)
    # Group creation
    group = create_group(:students => [student, student2, student3], :mentor => [mentor, mentor2], :program => program)
    # Archived
    create_meeting(start_time: time - 50.minutes, end_time: time - 20.minutes, :group_id => group.id, :members => [student.member, mentor.member], :owner_id => mentor.member.id)
    create_meeting(start_time: time - 60.minutes, end_time: time - 10.minutes, :group_id => group.id, :members => [student2.member, mentor.member], :owner_id => mentor.member.id)
    create_meeting(start_time: time - 50.minutes, end_time: time - 20.minutes, :group_id => group.id, :members => [student.member, mentor2.member], :owner_id => mentor2.member.id)
    # Archived no one attanding
    m = create_meeting(start_time: time - 2.days, end_time: time - 1.day, :group_id => group.id, :members => [student.member, mentor.member], :owner_id => mentor.member.id)
    m.member_meetings.map{|mm| mm.update_column(:attending, MemberMeeting::ATTENDING::NO)}
    # Upcoming
    create_meeting(start_time: 20.minutes.from_now, end_time: 50.minutes.from_now, :group_id => group.id, :members => [student.member, mentor2.member], :owner_id => mentor2.member.id)
    create_meeting(start_time: 20.minutes.from_now, end_time: 50.minutes.from_now, :group_id => group.id, :members => [student2.member, mentor.member], :owner_id => mentor.member.id)
    # detailed view
    assert_equal 2, group.meetings_activity[student.id].to_i
    assert_equal 2, group.meetings_activity[mentor.id].to_i
    assert_equal 1, group.meetings_activity[mentor2.id].to_i
    assert_equal 1, group.meetings_activity[student2.id].to_i
    assert_equal 0, group.meetings_activity[student3.id].to_i
    # Table view
    assert_equal 3, group.meetings_activity(student_role_id)[:role].to_i
    assert_equal 3, group.meetings_activity(mentor_role_id)[:role].to_i
    # Between Dates
    assert_equal 0, group.meetings_activity(mentor_role_id, {start_time: Time.now.utc, end_time: 1.minute.from_now})[:role].to_i
    assert_equal 2, group.meetings_activity(mentor_role_id, {start_time: Time.now.utc, end_time: 60.minutes.from_now})[:role].to_i
    assert_equal 0, group.meetings_activity(student_role_id, {start_time: 40.minutes.ago, end_time: Time.now.utc})[:role]
    assert_equal 3, group.meetings_activity(student_role_id, {start_time: 70.minutes.ago, end_time: Time.now.utc})[:role]
  end

  def test_survey_responses_activity
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attributes(:should_sync => true)
    new_user = users(:f_student)
    group = groups(:mygroup)
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    survey = programs(:albers).surveys.find_by(name: "Partnership Effectiveness")
    create_matrix_survey_question({survey: survey})
    tem_task = create_mentoring_model_task_template
    tem_task.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id })
    MentoringModel.trigger_sync(mentoring_model.id, I18n.locale)
 
    response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    user = group.mentors.where(id: users(:f_mentor).id).first
    student = group.students.where(id: users(:mkr_student).id).first
    task = group.mentoring_model_tasks.reload.where(:action_item_type => MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY).first
    
    task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
      ans = task.survey_answers.new(user: user, response_id: response_id, answer_value: {answer_text: "Good", question: ques}, last_answered_at: Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
 
    student_response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
      ans = task.survey_answers.new(user: student, response_id: student_response_id, answer_value: {answer_text: "Good", question: ques}, last_answered_at: Time.now.utc)
      ans.survey_question = ques
      ans.save!
    end
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
 
    assert_equal 2, group.survey_responses_activity
    assert_equal 1, group.survey_responses_activity(mentor_role_id)
    assert_equal 1, group.survey_responses_activity(student_role_id)
 
    group.update_members(group.mentors, group.students + [new_user])
    response_id = SurveyAnswer.maximum(:response_id).to_i + 1
    time_traveller(1.day.from_now) do
      task.action_item.survey_questions.where(:question_type => [CommonQuestion::Type::STRING , CommonQuestion::Type::TEXT, CommonQuestion::Type::MULTI_STRING]).each do |ques|
      ans = task.survey_answers.new(:user => new_user, :response_id => response_id, answer_value: {answer_text: "lorem ipsum3", question: ques}, :last_answered_at => Time.now.utc)
      ans.survey_question = ques
      ans.save!
      end
      task.action_item.survey_questions_with_matrix_rating_questions.matrix_rating_questions.each do |ques|
        ans = task.survey_answers.new(:user => new_user, :response_id => response_id, answer_value: {answer_text: "Good", question: ques}, :last_answered_at => Time.now.utc)
        ans.survey_question = ques
        ans.save!
      end
    end
 
    assert_equal 2, group.survey_responses_activity(student_role_id, {:start_time => program.created_at, :end_time => 2.days.from_now})
    assert_equal 1, group.survey_responses_activity(student_role_id, {:start_time => program.created_at, :end_time => Time.now.utc})
    assert_equal 1, group.survey_responses_activity(student_role_id, {:start_time => Time.now.utc + 1.hour, :end_time => 2.days.from_now})
    assert_equal 1, group.survey_responses_activity(mentor_role_id, {:start_time => program.created_at, :end_time => 2.days.from_now})
  end

  def test_tasks_activity
    group = groups(:mygroup)
    task1 = create_mentoring_model_task
    task2 = create_mentoring_model_task
    task2.update_attributes!(status: MentoringModel::Task::Status::DONE)

    tasks_activity_output = group.tasks_activity
    assert_equal_hash({users(:f_mentor).id => 1}, tasks_activity_output)

    task3 = create_mentoring_model_task({user: users(:mkr_student)})
    task4 = create_mentoring_model_task

    task3.update_attributes!(status: MentoringModel::Task::Status::DONE)
    task4.update_attributes!(status: MentoringModel::Task::Status::DONE)

    tasks_activity_output = group.tasks_activity
    assert_equal_hash({users(:f_mentor).id => 2, users(:mkr_student).id => 1}, tasks_activity_output)
  end

  def test_remove_member_meetings_when_user_is_removed_from_group
    #Removing a user from a group deletes corresponding member meetings for that user
    group = groups(:mygroup)
    mentor = group.mentors.first
    student = group.students.first
    new_user = users(:student_2)
    group.update_members(group.mentors, group.students + [new_user])
    time = Time.now
    meeting = create_meeting(
      start_time: time,
      end_time: time + 30.minutes,
      members: [mentor.member, student.member],
      program_id: group.program.id,
      group_id: group.id,
      owner_id: mentor.id
    )
    member_meeting = meeting.member_meetings.find_by(member_id: student.member)
    group.update_members(group.mentors, [new_user])
    assert_false MemberMeeting.exists?(member_meeting.id)
  end

  def test_remove_member_meetings_when_user_is_replaced_from_group
    #Replacing a user from a group deletes corresponding member meetings for that user
    group = groups(:mygroup)
    mentor = group.mentors.first
    student1 = group.students.first
    student2 = users(:student_2)
    student3 = users(:student_3)
    group.update_members(group.mentors, [student1, student2])
    time = Time.now
    meeting = create_meeting(
      start_time: time,
      end_time: time + 30.minutes,
      members: [mentor.member, student1.member, student2.member],
      program_id: group.program.id,
      group_id: group.id,
      owner_id: mentor.id
    )
    member_meeting = meeting.member_meetings.find_by(member_id: student2.member)
    group.update_members(group.mentors, [student1, student3])
    assert_false MemberMeeting.exists?(member_meeting.id)
  end

  def test_mentors_mentees_presence_for_draft
    program = programs(:albers)
    group = nil

    assert_nothing_raised do
      group = create_group(name: "Carrie Mathison", students: [], mentors: [], program: program, status: Group::Status::DRAFTED, creator_id: users(:f_admin).id)
    end

    assert_equal [], group.students
    assert_equal [], group.mentors

    assert_raise ActiveRecord::RecordInvalid, "Validation failed:" do
      group.publish(users(:f_admin), "test message")
    end

    assert_equal Group::Status::DRAFTED, group.reload.status

    group.students = [users(:f_student)]
    group.mentors = [users(:f_mentor)]
    group.save!

    assert_nothing_raised do
      group.publish(users(:f_admin), "test message")
    end

    assert_equal [users(:f_student)], group.students
    assert_equal [users(:f_mentor)], group.mentors
  end

  def test_mentors_mentees_presence_for_pending
    enable_project_based_engagements!
    program = programs(:albers)

    group = nil
    assert_nothing_raised do
      group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    end

    assert_equal [], group.students
    assert_equal [], group.mentors

    assert_raise ActiveRecord::RecordInvalid, "Validation failed:" do
      group.publish(users(:f_admin), "test message")
    end

    assert_equal Group::Status::PENDING, group.reload.status

    group.students = [users(:f_student)]
    group.mentors = [users(:f_mentor)]
    group.save!

    assert_nothing_raised do
      group.publish(users(:f_admin), "test message")
    end

    assert_equal [users(:f_student)], group.students
    assert_equal [users(:f_mentor)], group.mentors
  end

  def test_check_mentor_limit_check_needed
    enable_project_based_engagements!
    program = programs(:albers)
    group = groups(:mygroup)
    mentors = group.mentors
    students = group.students
    user = mentors.first
    user.update_attributes!(max_connections_limit: 2)
    assert_nothing_raised do
      group.update_members(mentors, students + program.student_users.limit(5))
    end
    group.reload
    assert_false group.mentor_limit_check_needed?
  end

  def test_check_mentor_limit_check_needed_for_closed_group
    program = programs(:albers)
    mentor = users(:f_mentor)
    students = program.student_users.limit(1)
    mentor.update_attributes!(max_connections_limit: 1)
    group = Group.new(program: program, students: students, mentors: [mentor])

    assert group.mentor_limit_check_needed?
    assert_false group.valid?
    assert_equal ["#{mentor.name} preferred not to have more than 1 students"], group.errors[:base]

    group.status = Group::Status::CLOSED
    group.closed_at         = Time.now
    group.termination_mode  = Group::TerminationMode::ADMIN
    group.closure_reason_id = program.default_closure_reasons.completed.first.id
    group.closed_by         = users(:f_admin)
    group.expiry_time       = group.get_group_expiry_time

    assert_false group.mentor_limit_check_needed?
    assert group.valid?
  end

  def test_published_scope
    enable_project_based_engagements!
    program = programs(:albers)

    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)

    assert_false program.groups.published.pluck(:id).include?(group.id)
    group.students = [users(:f_student)]
    group.mentors = [users(:f_mentor)]
    group.save!
    group.publish(users(:f_admin), "test message")
    assert program.reload.groups.published.pluck(:id).include?(group.id)
  end

  def test_group_pending
    enable_project_based_engagements!
    program = programs(:albers)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    assert group.pending?
    assert_not_nil group.pending_at
    assert_false group.active?
    group.students = [users(:f_student)]
    group.mentors = [users(:f_mentor)]
    group.save!
    group.publish(users(:f_admin), "test message")
    assert_false group.pending?
    assert_not_nil group.pending_at
    assert group.active?
  end

  def test_pending_at_validations
    enable_project_based_engagements!
    program = programs(:albers)
    group = program.groups.new(status: Group::Status::PENDING, skip_observer: true)
    assert_false group.valid?
    assert_equal ["can't be blank"], group.errors[:pending_at]
  end

  def test_accept_project_requests
    enable_project_based_engagements!
    program = programs(:albers)
    student_user = users(:student_3)
    student_role = program.get_role(RoleConstants::STUDENT_NAME)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    project_request = create_project_request(group, student_user)

    group.accept_project_requests!({student_role => [student_user]}, nil)
    assert_equal AbstractRequest::Status::ACCEPTED, project_request.reload.status
  end

  def test_update_members_with_pbe
    enable_project_based_engagements!
    program = programs(:albers)
    student_user = users(:student_3)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    project_request = create_project_request(group, student_user)

    group.update_members([], [student_user], nil)
    assert_equal AbstractRequest::Status::ACCEPTED, project_request.reload.status
  end

  def test_active_project_requests
    enable_project_based_engagements!
    program = programs(:albers)
    student_user = users(:student_3)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    project_request = create_project_request(group, student_user)
    assert_equal [project_request], group.active_project_requests
  end

  def test_active_project_requests_with_update_members_on_pbe_program
    program = programs(:pbe)
    student_user = users(:pbe_student_1)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    student_project_request = create_project_request(group, student_user)
    assert_equal [student_project_request], group.active_project_requests
    group.update_members([], [student_user])
    assert_equal AbstractRequest::Status::ACCEPTED, group.project_requests.pluck(:status).first
    group.reload
    assert_equal [], group.active_project_requests

    teacher_role = program.roles.find_by(name: "teacher")
    teacher_role.add_permission(RolePermission::SEND_PROJECT_REQUEST)
    teacher_user = users(:pbe_teacher_1)
    group.reload
    teacher_project_request = create_project_request(group, teacher_user)
    teacher_project_request.update_attribute :sender_role_id, teacher_role.id
    assert_equal [teacher_project_request], group.active_project_requests
    group.update_members([], [], student_user, other_roles_hash: {teacher_role => [teacher_user]})
    teacher_project_request.reload
    assert_equal AbstractRequest::Status::ACCEPTED, teacher_project_request.status
    group.reload
    assert_equal [], group.active_project_requests
  end

  def test_open_scope
    enable_project_based_engagements!
    program = programs(:albers)
    group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)

    assert_equal 7, program.groups.open_connections.size
    assert_equal (program.groups.active + [group]), program.groups.open_connections
  end

  def test_open_or_closed_scope
    enable_project_based_engagements!
    program = programs(:albers)

    open_groups = program.groups.open_connections.pluck(:id)
    closed_groups = program.groups.closed.pluck(:id)

    assert open_groups.present?
    assert closed_groups.present?

    assert_equal_unordered (open_groups + closed_groups), program.groups.open_or_closed.pluck(:id)
  end

  def test_recently_available_first_scope
    program = programs(:pbe)
    time_now = Time.parse("28/11/2017 10:00:00")
    Timecop.freeze(time_now) do
      groups(:group_pbe_0).update_columns(published_at: time_now + 10.seconds, pending_at: time_now + 15.seconds)
      groups(:group_pbe_1).update_columns(published_at: time_now - 10.seconds, pending_at: time_now + 2.seconds)
      groups(:group_pbe_2).update_columns(published_at: nil, pending_at: time_now + 20.seconds)
      groups(:group_pbe_3).update_columns(published_at: nil, pending_at: time_now + 1.second)
      groups(:group_pbe_4).update_columns(published_at: time_now + 5.seconds, pending_at: time_now + 10.seconds)
    end
    group_ids = program.groups.pending.recently_available_first.pluck(:id)
    assert_equal [groups(:group_pbe_2), groups(:group_pbe_3), groups(:group_pbe_0), groups(:group_pbe_4), groups(:group_pbe_1)].collect(&:id), group_ids
  end

  def test_active_or_pending_scope
    program = programs(:pbe)

    active_groups = program.groups.active.pluck(:id)
    pending_groups = program.groups.pending.pluck(:id)

    assert active_groups.present?
    assert pending_groups.present?

    assert_equal_unordered program.groups.active_or_pending.pluck(:id), active_groups + pending_groups
  end

  def test_reject_groups_with_ids_scope
    group1 = groups(:mygroup)
    group2 = groups(:group_2)

    assert Group.pluck(:id).include?(group1.id)
    assert Group.pluck(:id).include?(group2.id)

    assert Group.reject_groups_with_ids([]).pluck(:id).include?(group1.id)

    assert_false Group.reject_groups_with_ids([group1.id]).pluck(:id).include?(group1.id)
    assert Group.reject_groups_with_ids([group1.id]).pluck(:id).include?(group2.id)

    assert_false Group.reject_groups_with_ids([group1.id, group2.id]).pluck(:id).include?(group1.id)
    assert_false Group.reject_groups_with_ids([group1.id, group2.id]).pluck(:id).include?(group2.id)
  end

  def test_active_between_scope
    t1 = 1.year.from_now
    t2 = 2.years.from_now
    groups = Group.first(6)
    g0 = groups[0]
    g1 = groups[1]
    g2 = groups[2]
    g3 = groups[3]
    g4 = groups[4]
    g5 = groups[5]

    g0.update_columns(published_at: nil)
    g1.update_columns(published_at: t1 - 1.year, closed_at: t1 - 1.second)
    g2.update_columns(published_at: t1 - 1.year, closed_at: t1 + 1.second)
    g3.update_columns(published_at: t1 - 1.year, closed_at: t2 + 1.second)
    g4.update_columns(published_at: t1 + 1.second, closed_at: nil)
    g5.update_columns(published_at: t2 + 1.second, closed_at: nil)

    group_ids = Group.active_between(t1, t2).pluck(:id)

    assert group_ids.include?(g2.id)
    assert group_ids.include?(g3.id)
    assert group_ids.include?(g4.id)

    assert_false group_ids.include?(g0.id)
    assert_false group_ids.include?(g1.id)
    assert_false group_ids.include?(g5.id)
  end

  def test_max_limit_of_student_in_project_validation
    enable_project_based_engagements!
    program = programs(:albers)
    role_id = program.get_role(RoleConstants::STUDENT_NAME).id
    group_1 = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group_2 = create_group(name: "Project 2", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    group_3 = create_group(name: "Project 3", students: [], mentors: [], program: program, status: Group::Status::PENDING)

    setting_1 = group_1.membership_settings.create!(role_id: role_id, max_limit: 2)
    setting_2 = group_2.membership_settings.create!(role_id: role_id, max_limit: 4)

    stu_users = [users(:student_5), users(:student_6), users(:student_7)]
    # Case 1: exceeds student max limit
    group_1.reload
    assert_false group_1.update_members([], stu_users)
    # Case 2: not exceed student max limit
    assert  group_2.update_members([], stu_users)
    # Case 3: without student max limit
    assert group_3.update_members([], stu_users)
  end

  def test_add_remove_members_across_roles
    enable_project_based_engagements!
    program = programs(:albers)
    teacher_role = create_role(name: "teacher", program: program, for_mentoring: true)
    role_id = program.get_role(RoleConstants::STUDENT_NAME).id
    group_1 = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    stu_users = [users(:student_5), users(:student_6), users(:student_7)]
    stu_users.each do |user|
      user.roles += [teacher_role]
    end

    mentoring_model = mentoring_models(:mentoring_models_1)
    group_1.mentoring_model = mentoring_model
    group_1.save!
    mentoring_model.allow_forum = true
    mentoring_model.allow_messaging = false
    mentoring_model.save(validate: false)
    forum = group_1.reload_forum

    assert_false forum.subscribed_by?(stu_users.first)
    assert_difference "Subscription.count", 3 do
      assert_difference "Connection::CustomMembership.count", 3 do
        group_1.update_members([], [], nil, other_roles_hash: {teacher_role => stu_users})
      end
    end

    assert forum.subscribed_by?(users(:student_5))
    assert_difference "Subscription.count", -1 do
      assert_difference "Connection::CustomMembership.count", -1 do
        assert_no_difference "Group.count" do
          group_1.update_members([], [], nil, other_roles_hash: {teacher_role => stu_users - [users(:student_5)]})
        end
      end
    end
    assert_false forum.subscribed_by?(users(:student_5))

    assert_difference "Subscription.count", -2 do
      assert_difference "Connection::CustomMembership.count", -2 do
        assert_no_difference "Group.count" do
          group_1.update_members([], [], nil, other_roles_hash: {teacher_role => []})
        end
      end
    end

    assert_equal [], group_1.reload.members

    assert_difference "Subscription.count", 3 do
      assert_difference "Connection::MenteeMembership.count", 3 do
        assert_no_difference "Group.count" do
          group_1.update_members([], stu_users)
        end
      end
    end

    assert_difference "Subscription.count", -3 do
      assert_difference "Connection::MenteeMembership.count", -3 do
        assert_no_difference "Group.count" do
          group_1.update_members([], [])
        end
      end
    end
  end

  def test_available_projects
    program = programs(:albers)
    enable_project_based_engagements!
    pending_group = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    role_ids = program.mentoring_role_ids

    # Pending group
    assert program.groups.pending.include?(pending_group)
    assert program.groups.pending.available_projects(role_ids).include?(pending_group)
    assert_false program.groups.pending.available_projects(role_ids).include?(groups(:mygroup))
    assert program.groups.available_projects(role_ids).include?(groups(:mygroup))

    role_ids.each do |role_id|
      pending_group.membership_settings.create!(role_id: role_id, max_limit: 2)
    end
    assert program.groups.pending.available_projects(role_ids).include?(pending_group)

    pending_group.update_members([users(:f_mentor)], [users(:f_student)])
    assert program.groups.pending.available_projects(role_ids).include?(pending_group)
    assert program.groups.pending.available_projects(role_ids).pending_less_than(3.days.ago).include?(pending_group)
    assert program.groups.pending.available_projects(role_ids).pending_less_than(4.days.ago).include?(pending_group)
    assert_false program.groups.pending.available_projects(role_ids).pending_less_than(1.days.from_now).include?(pending_group)

    pending_group.update_members([users(:f_mentor)], [users(:f_student), users(:student_3)])
    assert program.groups.pending.available_projects(role_ids).include?(pending_group)

    # Active group
    active_group = create_group(name: "Project 1", students: [users(:f_student)], mentors: [users(:f_mentor)], program: program, status: Group::Status::ACTIVE)
    assert program.groups.open_connections.include?(active_group)
    assert program.groups.open_connections.available_projects(role_ids).include?(active_group)
    assert_false program.groups.open_connections.available_projects(role_ids).include?(groups(:drafted_group_1))

    role_ids.each do |role_id|
      active_group.membership_settings.create!(role_id: role_id, allow_join: false)
    end
    assert_false program.groups.open_connections.available_projects(role_ids).include?(active_group)

    role_ids.each do |role_id|
      active_group.membership_settings.where(role_id: role_id).update_all(max_limit: 1, allow_join: nil)
    end
    assert_false program.groups.open_connections.available_projects(role_ids).include?(active_group)

    role_ids.each do |role_id|
      active_group.membership_settings.where(role_id: role_id).update_all(max_limit: 2, allow_join: nil)
    end
    assert program.groups.open_connections.available_projects(role_ids).include?(active_group)
  end

  def test_available_projects_for_students_and_mentors
    program = programs(:pbe)
    group_1 = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    roles = program.roles.for_mentoring.collect(&:id)
    student_role = program.roles.find_by(name: "student")
    teacher_role = program.roles.find_by(name: "teacher")

    # Testing the case when no max_slot slots is filled.
    group_1.membership_settings.destroy_all
    assert program.groups.pending.include?(group_1)
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)])
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert group_1.update_members([users(:pbe_mentor_1)], [], nil, other_roles_hash: {teacher_role => [users(:pbe_teacher_1), users(:pbe_teacher_2)]})
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    #Testing the case when max_slot for only a student is filled.
    group_1.membership_settings.destroy_all
    group_1.membership_settings.create!(role_id: student_role.id, max_limit: 2)
    assert group_1.update_members([], [])
    assert program.groups.pending.include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)])
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert_false program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)], nil, other_roles_hash: {teacher_role => [users(:pbe_teacher_1), users(:pbe_teacher_2)]})
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert_false program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    #Testing the case when max slot for only a teacher is filled
    group_1.membership_settings.destroy_all
    group_1.membership_settings.create!(role_id: teacher_role.id, max_limit: 2)
    # group_1.memberships.destroy_all
    assert group_1.update_members([], [])
    assert program.groups.pending.include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)], nil, other_roles_hash: {teacher_role => []})
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)], nil, other_roles_hash: {teacher_role => [users(:pbe_teacher_1), users(:pbe_teacher_2)]})
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert_false program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    #Testing the case when max slot for both student and teacher are filled
    group_1.membership_settings.destroy_all
    group_1.membership_settings.create!(role_id: teacher_role.id, max_limit: 2)
    group_1.membership_settings.create!(role_id: student_role.id, max_limit: 2)
    # group_1.memberships.destroy_all
    assert group_1.update_members([], [])
    assert program.groups.pending.include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)], nil, other_roles_hash: {teacher_role => []})
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert_false program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [], nil, other_roles_hash: {teacher_role => [users(:pbe_teacher_1), users(:pbe_teacher_2)]})
    assert program.groups.pending.available_projects(roles).include?(group_1)
    assert program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert_false program.groups.pending.available_projects([teacher_role.id]).include?(group_1)

    assert group_1.update_members([users(:pbe_mentor_1)], [users(:pbe_student_1), users(:pbe_student_2)], nil, other_roles_hash: {teacher_role => [users(:pbe_teacher_1), users(:pbe_teacher_2)]})
    assert_false program.groups.pending.available_projects([student_role.id, teacher_role.id]).include?(group_1)
    assert_false program.groups.pending.available_projects([student_role.id]).include?(group_1)
    assert_false program.groups.pending.available_projects([teacher_role.id]).include?(group_1)
  end

  def test_sync_with_template_when_group_not_found
    Group::MentoringModelUpdater.any_instance.expects(:sync).times(0)
    Group.sync_with_template(13243242, I18n.locale)
  end

  def test_sync_with_template
    Group::MentoringModelUpdater.any_instance.expects(:sync).once
    Group.sync_with_template(groups(:group_pbe_0).id, I18n.locale)
  end

  def test_meetings_enabled
    group = groups(:mygroup)
    assert_false group.meetings_enabled?

    programs(:albers).enable_feature(FeatureName::MENTORING_CONNECTION_MEETING)
    assert group.reload.meetings_enabled?
  end

  def test_scraps_enabled
    group = groups(:mygroup)
    assert_nil group.mentoring_model
    assert group.scraps_enabled?

    group = groups(:group_pbe)
    assert group.mentoring_model.present?
    group.mentoring_model.allow_messaging = true
    assert group.scraps_enabled?

    group.mentoring_model.allow_messaging = false
    assert_false group.scraps_enabled?
  end

  def test_forum_enabled
    group = groups(:mygroup)
    assert_nil group.mentoring_model
    assert_false group.forum_enabled?

    group = groups(:group_pbe)
    group.mentoring_model.allow_forum = false
    assert_false group.forum_enabled?

    group.mentoring_model.allow_forum = true
    assert group.forum_enabled?
  end

  def test_create_group_forum
    open_group = groups(:mygroup)
    drafted_group = groups(:drafted_group_1)
    assert_false open_group.forum_enabled?

    assert_no_difference "Forum.count" do
      assert_no_difference "Subscription.count" do
        open_group.create_group_forum
      end
    end

    assert_no_difference "Forum.count" do
      assert_no_difference "Subscription.count" do
        drafted_group.create_group_forum
      end
    end

    open_group.stubs(:forum_enabled?).returns(:true)
    assert_nil open_group.forum
    assert_difference "Forum.count" do
      assert_difference "Subscription.count", open_group.members.count do
        open_group.create_group_forum
      end
    end
    assert_equal Forum.last, open_group.forum
    assert_equal open_group.forum.subscribers, open_group.members

    assert_no_difference "Forum.count" do
      assert_no_difference "Subscription.count" do
        open_group.create_group_forum
      end
    end
  end

  def test_custom_memberships_and_custom_users
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    group = create_group(
      program: program,
      mentors: [users(:mentor_3), users(:mentor_4)],
      students: [users(:student_4), users(:student_5)],
      notes: "This is a test group"
    )

    teacher_role = create_role(name: "teacher", for_mentoring: true)
    user = users(:mentor_6)
    user.roles += [teacher_role]
    user.save!
    assert_equal [], group.custom_memberships
    assert_equal [], group.custom_users

    membership = group.custom_memberships.create!(
      user: user,
      role: teacher_role
    )
    assert_equal [user], group.reload.custom_users
    assert_equal [membership], group.custom_memberships
  end

  def test_add_and_remove_custom_users
    program = programs(:albers)
    role = create_role(name: "teacher", for_mentoring: true)
    allow_one_to_many_mentoring_for_program(program)
    group = create_group(
      program: program,
      mentors: [users(:mentor_3), users(:mentor_4)],
      students: [users(:student_4), users(:student_5)],
      notes: "This is a test group", status: Group::Status::PENDING
    )

    user = users(:mentor_5)
    user.roles += [role]
    user.save!
    user.reload
    assert_difference "Connection::CustomMembership.count" do
      group.add_and_remove_custom_users!(role, [users(:mentor_5)])
    end
    assert_equal [users(:mentor_5)], group.reload.custom_users

    user = users(:mentor_6)
    user.roles += [role]
    user.save!
    user.reload
    assert_difference "Connection::CustomMembership.count" do
      group.add_and_remove_custom_users!(role, [users(:mentor_5), users(:mentor_6)])
    end
    assert_equal [users(:mentor_5), users(:mentor_6)], group.reload.custom_users

    user = users(:mentor_7)
    user.roles += [role]
    user.save!
    user.reload
    assert_no_difference "Connection::CustomMembership.count" do
      group.add_and_remove_custom_users!(role, [users(:mentor_7), users(:mentor_6)])
    end
    assert_equal [users(:mentor_6), users(:mentor_7)], group.reload.custom_users

    assert_difference "Connection::CustomMembership.count", -2 do
      assert_no_difference "Group.count" do
        group.add_and_remove_custom_users!(role, [])
      end
    end

    assert_equal [], group.reload.custom_users
    assert_difference "Connection::Membership.count", -4 do
      assert_no_difference "Group.count" do
        group.update_members([], [], users(:f_mentor))
      end
    end

    assert_equal [], group.reload.custom_users
  end

  def test_proposed
    program = programs(:pbe)
    proposed_groups = program.groups.where(status: Group::Status::PROPOSED)
    role = program.get_role(RoleConstants::MENTOR_NAME)
    role.add_permission(RolePermission::PROPOSE_GROUPS)
    new_proposed_groups = []
    2.times do |index|
      new_proposed_groups[index] = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end
    2.times do |index|
      assert new_proposed_groups[index].proposed?
    end
    assert_equal_unordered new_proposed_groups + proposed_groups, program.groups.proposed
  end

  def test_rejected
    program = programs(:pbe)
    user = users(:f_admin_pbe)
    rejected_groups = program.groups.where(status: Group::Status::REJECTED)
    role = program.get_role(RoleConstants::STUDENT_NAME)
    role.add_permission(RolePermission::PROPOSE_GROUPS)
    new_rejected_groups = []
    2.times do |index|
      new_rejected_groups[index] = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: user, termination_reason: "Sample Reason", closed_at: Time.now)
    end
    2.times do |index|
      assert new_rejected_groups[index].rejected?
    end
    assert_equal_unordered new_rejected_groups + rejected_groups, program.groups.rejected
  end

  def test_withdrawn
    program = programs(:pbe)
    user = users(:f_admin_pbe)
    withdrawn_groups = program.groups.where(status: Group::Status::WITHDRAWN)
    new_withdrawn_groups = []
    2.times do |index|
      new_withdrawn_groups[index] = create_group(name: "Project 1", students: [users(:f_student_pbe)], mentors: [], program: program, status: Group::Status::WITHDRAWN, creator_id: users(:f_student_pbe).id, closed_by: user, termination_reason: "Sample Reason", closed_at: Time.now)
    end
    2.times do |index|
      assert new_withdrawn_groups[index].withdrawn?
    end
    assert_equal_unordered new_withdrawn_groups + withdrawn_groups, program.groups.withdrawn
  end

  def test_created_by
    program = programs(:pbe)
    scoped_groups = []
    program.roles.where(name: [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).each do |role|
      role.add_permission(RolePermission::PROPOSE_GROUPS)
    end
    2.times do |index|
      scoped_groups[index] = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::REJECTED, creator_id: users(:f_student_pbe).id, closed_by: users(:f_admin_pbe), termination_reason: "sample", closed_at: Time.now)
    end
    2.times do |index|
      scoped_groups[index + 2] = create_group(name: "Project 1", students: [], mentors: [], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    end
    assert_equal [groups(:proposed_group_1), groups(:proposed_group_2), groups(:rejected_group_1)] + scoped_groups[0..1], program.groups.created_by(users(:f_student_pbe))
    assert_equal [groups(:proposed_group_3), groups(:proposed_group_4), groups(:rejected_group_2), groups(:withdrawn_group_1)] + scoped_groups[2..3], program.groups.created_by(users(:f_mentor_pbe))
  end

  def test_send_email_to_admins_after_proposal
    program = programs(:pbe)
    proposer = users(:f_mentor_pbe)
    group = groups(:group_pbe_1)
    group.update_attributes!(created_by: proposer, status: Group::Status::PROPOSED)
    assert_emails((program.admin_users - [group.created_by]).size) do
      Group.send_email_to_admins_after_proposal(group.id, JobLog.generate_uuid)
    end
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)

    assert_equal "New mentoring connection proposal", email.subject
    assert_match /Good unique name/, mail_content
    assert_match /has proposed a new mentoring connection called.*#{group.name}/, mail_content
    assert_match /project_b/, mail_content
    assert_match /The mentoring connection is pending for your review - you can choose to either accept or reject the mentoring connection/, mail_content
    assert_match "View mentoring connection", mail_content
    assert_match "p/#{program.root}/groups/#{group.id}/profile?src=mail", mail_content
  end

  def test_send_group_accepted_emails
    assert_nil Group.send_group_accepted_emails(nil, "Hi Dude", false)
    proposer = users(:f_mentor_pbe)
    group = groups(:group_pbe_1)
    group.update_attributes!(created_by: proposer, status: Group::Status::PROPOSED)

    assert_emails 1 do
      Group.send_group_accepted_emails(group.id, "Hi Dude", false)
    end

    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_equal "Your proposed mentoring connection has been accepted!", email.subject
    assert_equal proposer.email, email.to.first
    assert_match /Hi Dude/, mail_content
    assert_match /Congratulations! We have accepted your proposed mentoring connection, #{group.name}, in/, mail_content
    assert_no_match /and made you owner for the same./, mail_content

    assert_emails 1 do
      Group.send_group_accepted_emails(group.id, "Hi Dude", true)
    end
    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_match /You are the owner of the #{group.name}./, mail_content
  end

  def test_send_group_rejected_emails
    assert_nil Group.send_group_rejected_emails(nil)
    proposer = users(:f_mentor_pbe)
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    group.terminate!(users(:f_admin_pbe), "You did not watch Breaking Bad", group.program.permitted_closure_reasons.first.id, Group::TerminationMode::REJECTION, Group::Status::REJECTED)

    assert_emails 1 do
      Group.send_group_rejected_emails(group.id)
    end

    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_equal "Your request to create Claire Underwood - Francis Underwood has not been approved", email.subject
    assert_equal proposer.email, email.to.first
    assert_match /Unfortunately, we have to reject your proposed mentoring connection/, mail_content
    assert_match /You did not watch Breaking Bad/, mail_content
  end

  def test_send_group_withdrawn_emails
    assert_nil Group.send_group_withdrawn_emails(nil)
    member = users(:f_mentor_pbe)
    program = programs(:pbe)
    group = create_group(name: "Who will sit on the Iron Throne?", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PENDING, creator_id: users(:f_mentor_pbe).id)
    group.terminate!(users(:f_admin_pbe), "All men must die", nil, Group::TerminationMode::WITHDRAWN, Group::Status::WITHDRAWN)

    assert_emails 1 do
      Group.send_group_withdrawn_emails(group.id)
    end

    assert_equal Group::Status::WITHDRAWN, group.reload.status
    check_group_state_change_unit(group, GroupStateChange.last, Group::Status::PENDING)
    assert_equal Group::TerminationMode::WITHDRAWN, group.termination_mode
    assert_equal "All men must die", group.termination_reason
    assert_equal users(:f_admin_pbe), group.closed_by

    email = ActionMailer::Base.deliveries.last
    mail_content = get_html_part_from(email)
    assert_equal "Your open mentoring connection, Who will sit on the Iron Throne? has been withdrawn", email.subject
    assert_equal member.email, email.to.first
    assert_match /Unfortunately, we have to withdraw your open mentoring connection, Who will sit on the Iron Throne?/, mail_content
    assert_match /All men must die/, mail_content
  end

  def test_terminate_with_status
    program = programs(:pbe)
    group = create_group(name: "Betty Draper", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    admin_user = users(:f_admin_pbe)
    assert_no_difference "RecentActivity.count" do
      assert_no_emails do
        group.terminate!(admin_user, "You did not watch House of Cards", group.program.permitted_closure_reasons.first.id, Group::TerminationMode::REJECTION, Group::Status::REJECTED)
      end
    end
    assert_equal Group::Status::REJECTED, group.reload.status
    check_group_state_change_unit(group, GroupStateChange.last, Group::Status::PROPOSED)
    assert_equal Group::TerminationMode::REJECTION, group.termination_mode
    assert_equal "You did not watch House of Cards", group.termination_reason
    assert_equal admin_user, group.closed_by
  end

  def test_owners
    group = groups(:mygroup)
    student = users(:mkr_student)
    mentor = users(:f_mentor)
    #0 owners
    assert_equal [], group.owners
    group.membership_of(mentor).update_attributes!(owner: true)
    group.reload
    #1 owner
    assert_equal [mentor], group.owners

    #2 owners
    group.membership_of(student).update_attributes!(owner: true)
    group.reload
    assert_equal_unordered [mentor, student], group.owners
  end

  def test_make_proposer_owner
    proposer = users(:f_mentor_pbe)
    program = programs(:pbe)
    group = create_group(name: "Claire Underwood - Francis Underwood", students: [], mentors: [users(:f_mentor_pbe)], program: program, status: Group::Status::PROPOSED, creator_id: users(:f_mentor_pbe).id)
    group.reload
    assert_equal [], group.owners
    group.make_proposer_owner!
    group.reload
    assert_equal [proposer], group.owners
  end

  def test_survey_answers_associations_and_unique_survey_answers
    survey = surveys(:two)
    group = groups(:mygroup)
    program = group.program
    user = group.mentors.first

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attributes(should_sync: true)
    group.update_attributes(mentoring_model_id: mentoring_model.id)

    task_template = create_mentoring_model_task_template
    task_template.update_attributes!({action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, :role => program.roles.with_name([RoleConstants::MENTOR_NAME]).first})
    task = group.mentoring_model_tasks.reload.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, connection_membership_id: group.mentor_memberships.first.id).first

    survey.update_user_answers({common_questions(:q2_name).id => "Sunny", common_questions(:q2_location).id => "Chennai", common_questions(:q2_from).id => "Earth"}, {user_id: user.id, group_id: group.id})
    survey.update_user_answers({common_questions(:q2_name).id => "Bunny", common_questions(:q2_location).id => "Seattle", common_questions(:q2_from).id => "Krypton"}, {user_id: user.id, task_id: task.id})
    survey.update_user_answers({common_questions(:q2_name).id => "Bunny", common_questions(:q2_location).id => "Chennai", common_questions(:q2_from).id => "Krypton"}, {user_id: user.id, task_id: task.id})

    assert_equal 6, group.survey_answers.count
    assert_equal 2, group.unique_survey_answers.count
    assert_equal 2, group.unique_survey_answers(false, nil, skip_select: true).count
    assert_equal 2, group.unique_survey_answers(true, Time.now.utc-1.day..Time.now.utc+1.day).count
    assert_equal 0, group.unique_survey_answers(true, Time.now.utc+1.day..Time.now.utc+2.days).count
  end

  def test_group_membership_roles
    group = groups(:mygroup)
    program = programs(:albers)
    mentoring_roles = program.roles.where(name: RoleConstants::MENTORING_ROLES)
    assert_equal_unordered mentoring_roles, group.membership_roles
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    group = create_group(:students => [users(:f_student), users(:f_mentor_student)], :mentors => [users(:f_mentor)])
    assert_equal_unordered mentoring_roles, group.membership_roles
  end

  def test_with_published_at
    program = programs(:albers)
    group = groups(:mygroup)
    assert program.groups.with_published_at.include?(group)
    group.update_column(:published_at, nil)
    assert_false program.groups.with_published_at.include?(group.reload)
  end

  def test_after_destroy_callbacks_are_called_only_once
    group = groups(:mygroup)
    group.state_changes.each do |sc|
      DelayedEsDocument.expects(:delayed_delete_es_document).with(GroupStateChange, sc.id)
    end
    DelayedEsDocument.expects(:delayed_delete_es_document).with(Group, group.id)
    group.meetings.pluck(:id).each do |meeting_id|
      DelayedEsDocument.expects(:delayed_delete_es_document).with(Meeting, meeting_id)
    end
    group.destroy
  end

  def test_admin_enter_engagement_area
    user = users(:f_admin)
    is_super_console = false
    group = groups(:mygroup)

    assert group.admin_enter_mentoring_connection?(user, is_super_console)

    group.program.admin_access_to_mentoring_area = Program::AdminAccessToMentoringArea::DISABLED
    group.program.save!
    group.program.reload

    assert_false group.admin_enter_mentoring_connection?(user, is_super_console)

    is_super_console = true
    assert group.admin_enter_mentoring_connection?(user, is_super_console)
  end

  def test_update_attribute_skipping_observer
    group = groups(:mygroup)
    group.skip_observer = false
    assert group.global
    assert_no_emails do
      group.offered_to = users(:mkr_student)
      group.actor = users(:f_mentor)
      group.update_attribute_skipping_observer(:global, false)
    end
    assert_false group.skip_observer
    assert_false group.global
  end

  def test_feedback_responses_association
    program = programs(:albers)
    group = groups(:mygroup)
    mentee = group.students.first
    mentor = group.mentors.first
    feedback_form = program.feedback_forms.of_type(Feedback::Form::Type::COACH_RATING).first

    response = Feedback::Response.create_from_answers(mentee, mentor, 4, group, feedback_form, {})

    assert group.feedback_responses.include?(response)

    # destroying group
    assert_equal response.group, group
    group.destroy
    response.reload
    assert_false response.group.present?
  end

  def test_send_coach_rating_notification
    closed_group = groups(:group_4)
    assert_equal 2, closed_group.members.count

    Program.any_instance.expects(:coach_rating_enabled?).returns(false)
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_coach_rating_notification(closed_group.id, "something")
      end
    end

    Program.any_instance.expects(:coach_rating_enabled?).at_least_once.returns(true)
    assert_difference "JobLog.count", 2 do
      assert_emails 1 do
        Group.send_coach_rating_notification(closed_group.id, "something_new")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_coach_rating_notification(closed_group.id, "something_new")
      end
    end

    multi_group = groups(:multi_group)

    assert_false multi_group.closed?
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_coach_rating_notification(multi_group.id, "something")
      end
    end

    multi_group.update_column(:status, Group::Status::CLOSED)
    assert_equal 3, multi_group.students.count
    assert_equal 3, multi_group.mentors.count
    assert_difference "JobLog.count", 12 do
      assert_emails 9 do
        Group.send_coach_rating_notification(multi_group.id, "something")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_coach_rating_notification(0, "newer")
      end
    end
  end

  def test_send_group_creation_notification_to_members
    group = groups(:multi_group)
    assert_equal 3, group.students.count
    assert_equal 3, group.mentors.count
    assert_equal 0, group.custom_users.count

    assert_difference "JobLog.count", 6 do
      assert_emails 6 do
        Group.send_group_creation_notification_to_members(group.id, group.get_role_id_user_ids_map, "Test Group Creation Reason", "uuid1")
      end
    end

    emails = ActionMailer::Base.deliveries.last(6)
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    assert_equal_unordered ["You have been assigned a mentor!", "Connect with your students!"], emails.collect(&:subject).uniq
    assert_match /Message from the administrator: <br\/> &quot; Test Group Creation Reason &quot;/, get_html_part_from(emails.last)

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_creation_notification_to_members(group.id, group.get_role_id_user_ids_map, nil, "uuid1")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_creation_notification_to_members(0, group.get_role_id_user_ids_map, nil, "uuid2")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_creation_notification_to_members(group.id, {}, nil, "uuid3")
      end
    end

    ChronusMailer.expects(:group_creation_notification_to_students).times(3).returns(stub(:deliver_now))
    ChronusMailer.expects(:group_creation_notification_to_mentor).times(3).returns(stub(:deliver_now))
    ChronusMailer.expects(:group_creation_notification_to_custom_users).never.returns(stub(:deliver_now))
    Group.send_group_creation_notification_to_members(group.id, group.get_role_id_user_ids_map, nil, "uuid4")
  end

  def test_send_group_termination_mails
    group = groups(:group_4)
    assert_equal 2, group.members.count
    assert group.closed?

    assert_difference "JobLog.count", 2 do
      assert_emails 2 do
        Group.send_group_termination_notification(group.id, nil, "uuid1")
      end
    end

    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    assert_equal ["Your mentoring connection, #{group.name} has come to a close"], emails.collect(&:subject).uniq

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_termination_notification(group.id, nil, "uuid1")
      end
    end

    mentor = group.mentors.first
    group.update_column(:termination_mode, Group::TerminationMode::LEAVING)

    assert_difference "JobLog.count", 2 do
      assert_emails 2 do
        Group.send_group_termination_notification(group.id, mentor.id, "uuid2")
      end
    end

    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    assert_equal ["Your mentoring connection, #{group.name} has come to a close"], emails.collect(&:subject).uniq
    assert get_text_part_from(emails.last).include?("Closed due to #{mentor.name} leaving the mentoring connection")

    group.update_column(:status, Group::Status::ACTIVE)
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_termination_notification(group.id, nil, "uuid3")
      end
    end

    group.update_column(:status, Group::Status::CLOSED)
    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_termination_notification(0, nil, "uuid4")
      end
    end
  end

  def test_send_group_reactivation_mails
    group = groups(:multi_group)
    assert_equal 6, group.members.count

    assert_difference "JobLog.count", 6 do
      assert_emails 6 do
        Group.send_group_reactivation_mails(group.id, users(:f_admin), group.member_ids, "Reactivation reason 1", "uuid1")
      end
    end

    emails = ActionMailer::Base.deliveries.last(6)
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    assert_equal ["Your mentoring connection has been reactivated"], emails.collect(&:subject).uniq
    assert_match /Reason for reactivation:<br\/>'Reactivation reason 1'/, get_html_part_from(emails.last)

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_reactivation_mails(group.id, users(:f_admin), group.member_ids, nil, "uuid1")
      end
    end

    group_member_ids = group.member_ids
    new_mentor = users(:psg_mentor)
    group.update_members(group.mentors + [new_mentor], group.students)
    assert_difference "JobLog.count", 6 do
      assert_emails 6 do
        Group.send_group_reactivation_mails(group.id, nil, group_member_ids, nil, "uuid2")
      end
    end

    emails = ActionMailer::Base.deliveries.last(6)
    assert_false emails.collect(&:to).flatten.include?(new_mentor.email)

    group.update_column(:status, Group::Status::CLOSED)

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_reactivation_mails(group.id, nil, group.member_ids, nil, "uuid3")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_reactivation_mails(0, nil, group.member_ids, nil, "uuid4")
      end
    end

    assert_no_difference "JobLog.count" do
      assert_no_emails do
        Group.send_group_reactivation_mails(group.id, nil, [], nil, "uuid5")
      end
    end
  end

  def test_has_groups_proposed_by_role
    program = programs(:pbe)

    mentor_role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = program.roles.find_by(name: RoleConstants::STUDENT_NAME)
    admin_role = program.roles.find_by(name: RoleConstants::ADMIN_NAME)

    proposed_groups_roles = program.groups.proposed.collect(&:created_by).collect(&:roles).flatten.uniq

    assert proposed_groups_roles.include?(mentor_role)
    assert Group.has_groups_proposed_by_role(mentor_role)

    assert proposed_groups_roles.include?(mentee_role)
    assert Group.has_groups_proposed_by_role(mentee_role)

    assert_false proposed_groups_roles.include?(admin_role)
    assert_false Group.has_groups_proposed_by_role(admin_role)
  end

  def test_auto_publish_circles
    g1 = groups(:group_pbe)
    g2 = groups(:proposed_group_1)
    g3 = groups(:proposed_group_2)
    g4 = groups(:proposed_group_3)
    g5 = groups(:proposed_group_4)

    current_time = Time.now
    Time.stubs(:now).returns(current_time.beginning_of_day + 2.hours)

    assert g1.program.allow_circle_start_date?

    g1.update_attributes!(status: Group::Status::PENDING, start_date: Time.now - 2.hours)
    g2.update_attributes!(status: Group::Status::PENDING, start_date: Time.now + 1.day)
    g3.update_attributes!(status: Group::Status::PENDING, start_date: Time.now - 3.day)
    g4.update_attributes!(status: Group::Status::PENDING, start_date: Time.now - 1.hour, auto_publish_failure_mail_sent_time: 2.days.ago)

    assert g1.mentors.present?
    assert g1.students.present?
    assert_false g2.mentors.present?
    assert g2.students.present?
    assert_false g3.mentors.present?
    assert g3.students.present?
    assert g4.mentors.present?
    assert_false g4.students.present?
    assert g5.mentors.present?
    assert_false g5.students.present?

    g2.update_members([users(:pbe_mentor_1)], g2.students)
    g5.update_members(g5.mentors, [users(:pbe_student_1)])

    Group.any_instance.stubs(:owners).returns([users(:f_mentor_pbe)])

    assert_emails 3 do
      Group.auto_publish_circles
    end

    assert g1.reload.published?
    assert g2.reload.pending?
    assert g3.reload.pending?
    assert g4.reload.pending?
    assert g5.reload.proposed?
    assert g4.auto_publish_failure_mail_sent_time.to_i, (current_time.beginning_of_day + 2.hours).to_i

    email = ActionMailer::Base.deliveries.last
    assert_match("Your mentoring connection, #{g3.name} didn't start on", email.subject)
  end

  def test_get_role_id_user_ids_map
    group = groups(:multi_group)
    program = group.program

    role_id_users_ids_hash = {}
    role_id_users_ids_hash[program.roles.find_by(name: RoleConstants::STUDENT_NAME).id] = group.student_ids
    role_id_users_ids_hash[program.roles.find_by(name: RoleConstants::MENTOR_NAME).id] = group.mentor_ids

    assert role_id_users_ids_hash, group.get_role_id_user_ids_map

    teacher_role = create_role(name: "teacher", program: program, for_mentoring: true)
    stu_users = [users(:student_5), users(:student_6), users(:student_7)]
    stu_users.each do |user|
      user.roles += [teacher_role]
    end
    group.update_members([], [], nil, other_roles_hash: {teacher_role => stu_users})
    role_id_users_ids_hash[teacher_role.id] = stu_users.collect(&:id)

    assert role_id_users_ids_hash, group.get_role_id_user_ids_map
  end

  def test_get_mentoring_model
    group = groups(:mygroup)
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentoring_model = program.reload.default_mentoring_model
    assert_equal group.get_mentoring_model, mentoring_model
    new_model = create_mentoring_model
    group.update_attribute(:mentoring_model_id, new_model.id)
    assert_equal group.reload.get_mentoring_model, new_model
    new_model.destroy
    assert_equal group.reload.get_mentoring_model, mentoring_model
  end

  def test_group_checkins
    group = groups(:mygroup)
    task = create_mentoring_model_task(group: group)
    group_checkins_last_duration = group.group_checkins_duration
    group_checkins_last_size = group.group_checkins.count
    task_checkin1 = create_task_checkin(task, :duration => 60)
    task_checkin2 = create_task_checkin(task, :duration => 45)
    assert_equal group.group_checkins.last(2), [task_checkin1, task_checkin2]
    assert_equal group.group_checkins_duration, 105 + group_checkins_last_duration
    assert_equal group.task_checkins.last(2), [task_checkin1, task_checkin2]
    assert_equal group.group_checkins_duration(MentoringModel::Task.name), 105

    member_meeting = member_meetings(:member_meetings_1)
    meeting_checkin1 = create_meeting_checkin(member_meeting, :duration => 30)
    meeting_checkin2 = create_meeting_checkin(member_meeting, :duration => 15)
    assert_equal group.meeting_checkins.last(2), [meeting_checkin1, meeting_checkin2]
    assert_equal group.group_checkins_duration(MemberMeeting.name), 45 + group_checkins_last_duration
    updated_checkin_count = group_checkins_last_size + 4
    assert_equal group.group_checkins.count, updated_checkin_count

    group.group_checkins.reload
    assert_equal group.group_checkins.last(4), [task_checkin1, task_checkin2, meeting_checkin1, meeting_checkin2]
    assert_equal group.group_checkins_duration, 150 + group_checkins_last_duration

    assert_difference 'GroupCheckin.count', -(updated_checkin_count) do
      assert_difference 'Group.count', -1 do
        assert_nothing_raised do
          group.destroy
        end
      end
    end
  end

  def test_close_without_closure_reason
    g = groups(:mygroup)
    admin_user = users(:f_admin)
    g.status             = Group::Status::CLOSED
    g.termination_mode   = Group::TerminationMode::ADMIN
    g.closure_reason_id  = nil
    g.termination_reason = "Test termination"
    g.closed_by          = admin_user
    g.closed_at          = Time.now
    assert_false g.valid?
    g.closure_reason_id  = g.program.default_closure_reasons.completed.first.id
    assert g.valid?
  end

  def test_get_rolewise_slots_details
    program = programs(:pbe)
    group = groups(:group_pbe_0)
    group_view = program.group_view
    mentor_role_id = program.roles.where(name: RoleConstants::MENTOR_NAME).first.id
    student_role_id = program.roles.where(name: RoleConstants::STUDENT_NAME).first.id
    teacher_role_id = program.roles.where(name: RoleConstants::TEACHER_NAME).first.id

    group_view_columns_count = group_view.group_view_columns.size
    GroupViewColumn::Columns::Defaults::ROLE_BASED_COLUMNS.each_with_index do |column_key, index|
      group_view.group_view_columns.create!(column_key: column_key, position: group_view_columns_count + index, ref_obj_type: GroupViewColumn::ColumnType::NONE, role_id: teacher_role_id)
    end
    group.membership_settings.create!(role_id: mentor_role_id, max_limit: 15)
    group.membership_settings.create!(role_id: teacher_role_id, max_limit: 5)

    details_hash = Group.get_rolewise_slots_details([group.id], true, true)[group.id]
    assert_equal 15, details_hash[mentor_role_id][:total_slots]
    assert_equal 1, details_hash[mentor_role_id][:slots_taken]
    assert_nil details_hash[student_role_id][:total_slots]
    assert_equal 2, details_hash[student_role_id][:slots_taken]
    assert_equal 5, details_hash[teacher_role_id][:total_slots]
    assert_equal 0, details_hash[teacher_role_id][:slots_taken]

    details_hash = Group.get_rolewise_slots_details([group.id], false, true)[group.id]
    assert_empty details_hash.collect {|role_id, details| details[:total_slots]}.compact

    details_hash = Group.get_rolewise_slots_details([group.id], true, false)[group.id]
    assert_empty details_hash.collect {|role_id, details| details[:slots_taken]}.compact
  end

  def test_get_users_and_members
    program = programs(:pbe)
    group = groups(:group_pbe_0)
    group_id = group.id
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    role_ids = [mentor_role_id, student_role_id, teacher_role_id, nil]
    role_users_array = [group.mentors, group.students, group.custom_users, group.members]

    assert_equal role_users_array, role_ids.collect { |role_id| group.get_users(role_id) }

    role_user_ids_array = [group.mentor_ids, group.student_ids, group.custom_user_ids, group.member_ids]
    assert_equal role_user_ids_array, role_ids.collect { |role_id| group.get_user_ids(role_id) }

    role_member_ids_array = role_users_array.collect { |role_users| role_users.collect(&:member_id) }
    assert_equal role_member_ids_array, role_ids.collect { |role_id| group.get_member_ids(role_id) }

    expected_hash = {}
    group.mentor_ids.each {|mentor_id| (expected_hash[group_id] ||= {})[mentor_id] = mentor_role_id}
    group.student_ids.each {|student_id| (expected_hash[group_id] ||= {})[student_id] = student_role_id}
    group.custom_user_ids.each {|custom_user_id| (expected_hash[group_id] ||= {})[custom_user_id] = teacher_role_id}

    assert_equal_hash expected_hash, Group.get_group_id_user_id_role_id_map([group_id])
    assert_equal group.mentor_ids, Group.get_group_id_user_id_role_id_map([group_id], [mentor_role_id])[group_id].keys
    assert_equal group.student_ids, Group.get_group_id_user_id_role_id_map([group_id], [student_role_id])[group_id].keys

    expected_hash = {}
    group.mentors.pluck(:member_id).each {|mentor_id| (expected_hash[group_id] ||= {})[mentor_id] = mentor_role_id}
    group.students.pluck(:member_id).each {|student_id| (expected_hash[group_id] ||= {})[student_id] = student_role_id}
    group.custom_users.pluck(:member_id).each {|custom_user_id| (expected_hash[group_id] ||= {})[custom_user_id] = teacher_role_id}

    assert_equal_hash expected_hash, Group.get_group_id_member_id_role_id_map([group_id])
    assert_equal group.mentors.pluck(:member_id), Group.get_group_id_member_id_role_id_map([group_id], [mentor_role_id])[group_id].keys
    assert_equal group.students.pluck(:member_id), Group.get_group_id_member_id_role_id_map([group_id], [student_role_id])[group_id].keys
  end

  def test_get_rolewise_post_activity
    group = groups(:group_pbe_0)
    program = group.program
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    mentor = group.mentors.first
    student = group.students.first
    group.stubs(:active?).returns(true)
    group.stubs(:forum_enabled?).returns(true)

    group.create_group_forum
    topic1 = create_topic(forum: group.forum, user: mentor)

    create_post(topic: topic1, user: student)
    create_post(topic: topic1, user: mentor)
    create_post(topic: topic1, user: student)
    create_post(topic: topic1, user: mentor)
    create_post(topic: topic1, user: student)

    group_id_role_id_posts_count_map = Group.get_rolewise_posts_activity([group], [])
    role_id_posts_count_hash = group.get_rolewise_posts_activity_for_group.collect{|h| [h.keys.first, h.values.first] }.to_h
    assert_equal 2, role_id_posts_count_hash["mentor"]
    assert_equal 2, group_id_role_id_posts_count_map[group.id][mentor_role_id]
    assert_equal 3, role_id_posts_count_hash["student"]
    assert_equal 3, group_id_role_id_posts_count_map[group.id][student_role_id]
    assert_equal 0, role_id_posts_count_hash["teacher"]
    assert_nil group_id_role_id_posts_count_map[group.id][teacher_role_id]

    group_id_role_id_posts_count_map = Group.get_rolewise_posts_activity([group], [mentor_role_id])
    assert_equal 2, role_id_posts_count_hash["mentor"]
    assert_equal 2, group_id_role_id_posts_count_map[group.id][mentor_role_id]
    assert_equal 3, role_id_posts_count_hash["student"]
    assert_nil group_id_role_id_posts_count_map[group.id][student_role_id]
    assert_equal 0, role_id_posts_count_hash["teacher"]
    assert_nil group_id_role_id_posts_count_map[group.id][teacher_role_id]
  end

  def test_get_rolewise_login_activity
    program = programs(:pbe)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    teacher_role_id = program.roles.find_by(name: RoleConstants::TEACHER_NAME).id
    group = groups(:group_pbe_0)
    group.memberships.where(role_id: mentor_role_id).update_all(login_count: 3)
    group.memberships.where(role_id: student_role_id).update_all(login_count: 4)
    group_id_role_id_login_count_hash = Group.get_rolewise_login_activity([group.id])
    role_id_login_count_hash = group.get_rolewise_login_activity_for_group.collect{|h| [h.keys.first, h.values.first] }.to_h
    
    assert_equal 3, role_id_login_count_hash["mentor"]
    assert_equal 3, group_id_role_id_login_count_hash[group.id][mentor_role_id]
    assert_equal 8, role_id_login_count_hash["student"]
    assert_equal 8, group_id_role_id_login_count_hash[group.id][student_role_id]
    assert_nil group_id_role_id_login_count_hash[group.id][teacher_role_id]
    assert_equal_hash({}, Group.get_rolewise_login_activity([]))
  end

  def test_get_rolewise_scraps_activity
    program = programs(:albers)
    column_keys = program.group_view.group_view_columns.pluck(:column_key)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    student_role_id = program.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    group = groups(:mygroup)

    group_id_role_id_scraps_count_hash = Group.get_rolewise_scraps_activity([group.id], [])
    role_id_scraps_count_hash = group.get_rolewise_messages_activity_for_group.collect{|h| [h.keys.first, h.values.first] }.to_h

    assert_equal 4, role_id_scraps_count_hash["mentor"]
    assert_equal 4, group_id_role_id_scraps_count_hash[group.id][mentor_role_id]
    assert_equal 2, role_id_scraps_count_hash["student"]
    assert_equal 2, group_id_role_id_scraps_count_hash[group.id][student_role_id]

    group_id_role_id_scraps_count_hash = Group.get_rolewise_scraps_activity([group.id], [mentor_role_id])
    assert_equal 4, role_id_scraps_count_hash["mentor"]
    assert_equal 4, group_id_role_id_scraps_count_hash[group.id][mentor_role_id]
    assert_equal 2, role_id_scraps_count_hash["student"]
    assert_nil group_id_role_id_scraps_count_hash[group.id][student_role_id]

    assert_equal_hash({}, Group.get_rolewise_scraps_activity([], [mentor_role_id]))
    assert_equal_hash({}, Group.get_rolewise_scraps_activity([], []))
  end

  def test_get_role_based_details
    program = programs(:albers)
    mentor_role_id = program.roles.find_by(name: RoleConstants::MENTOR_NAME).id
    admin_role_id = program.roles.find_by(name: RoleConstants::ADMIN_NAME).id
    group = groups(:mygroup)
    Group.expects(:get_rolewise_slots_details).once
    Group.expects(:get_rolewise_login_activity).once
    Group.expects(:get_rolewise_scraps_activity).once
    Group.expects(:get_rolewise_posts_activity).once
    program.group_view.group_view_columns.create!(column_key: GroupViewColumn::Columns::Key::POSTS_ACTIVITY, role_id: mentor_role_id)
    role_details_hash = Group.get_role_based_details([group], program.group_view.group_view_columns.reload)
    assert role_details_hash.has_key?(:slot_details)
    assert role_details_hash.has_key?(:login_activity)
    assert role_details_hash.has_key?(:scraps_activity)
    assert role_details_hash.has_key?(:posts_activity)
    assert role_details_hash.has_key?(:role_id_name_hash)
    assert_equal "mentor", role_details_hash[:role_id_name_hash][mentor_role_id]
    assert_equal "admin", role_details_hash[:role_id_name_hash][admin_role_id]
  end

  def test_get_student_ids_mentor_ids
    output = []
    assert_empty Group.get_student_ids_mentor_ids([0])

    group = groups(:mygroup)
    output << [[users(:mkr_student).id], [users(:f_mentor).id]]
    assert_equal output, Group.get_student_ids_mentor_ids([group.id])

    group_2 = groups(:group_4)
    group_3 = groups(:group_inactive)
    output << [[users(:student_4).id], [users(:requestable_mentor).id]]
    output << [[users(:student_2).id], [users(:mentor_1).id]]
    assert_equal_unordered output, Group.get_student_ids_mentor_ids([group.id, group_2.id, group_3.id])
  end

  def test_get_non_bulk_match_drafted_groups
    program = programs(:albers)
    group_1 = groups(:drafted_group_1)
    group_2 = groups(:drafted_group_2)
    group_1_mentor = group_1.mentors.first
    group_1_student = group_1.students.first
    group_2_mentor = group_2.mentors.first
    group_2_student = group_2.students.first
    student_id_mentor_id_map = { group_1_student.id => group_1_mentor.id, group_2_student.id => group_2_mentor.id }

    assert_nil (group_1.bulk_match || group_2.bulk_match)
    assert_equal_hash( { group_1_student.id => group_1, group_2_student.id => group_2 }, Group.get_non_bulk_match_drafted_groups(student_id_mentor_id_map))

    group_1.bulk_match = program.bulk_matches.first
    group_1.save!
    assert_equal_hash( { group_2_student.id => group_2 }, Group.get_non_bulk_match_drafted_groups(student_id_mentor_id_map))

    group_2.publish(program.admin_users.first, "test message")
    assert_equal({}, Group.get_non_bulk_match_drafted_groups(student_id_mentor_id_map))
  end

  def test_reverse_inside_get_non_bulk_match_drafted_groups
    program = programs(:albers)
    group_1 = groups(:drafted_group_1)
    group_1_mentor = group_1.mentors.first
    group_1_student = group_1.students.first
    return_list = group_1.memberships.order(:user_id)
    Group.any_instance.stubs(:memberships).returns(return_list)
    student_id_mentor_id_map = { group_1_student.id => group_1_mentor.id}
    assert_equal_hash( { group_1_student.id => group_1}, Group.get_non_bulk_match_drafted_groups(student_id_mentor_id_map))
  end

  def test_name
    group = groups(:mygroup)
    assert_equal "name & madankumarrajan", group.name

    group.name = "name & madankumarrajanname & madankumarrajanname & madankumarrajanname & madankumarrajanname & madankumarrajan"
    assert_equal "name & madankumarrajanname & madankumarrajanname & madankumarrajanname & madankumarrajanname & madankumarrajan", group.name
    assert_equal "name & madankumarrajanname & madankumarrajanname & madankumarrajanname & madankumarrajanname & madankumarrajan", group.name(false)
    assert_equal "name & madankumarrajanname ...", group.name(true)
  end

  def test_days_before_expiry
    group = groups(:mygroup)
    current_time = Time.now
    Time.stubs(:now).returns(current_time)
    expiry_time = Time.now + 30.days
    group.expects(:expiry_time).returns(expiry_time)
    assert_equal 30, group.days_before_expiry
  end

  def test_initial_student_mentor_pair
    group = groups(:mygroup)
    student = group.students.first
    mentor = group.mentors.first
    assert_equal [student.id, mentor.id], group.initial_student_mentor_pair

    new_student = users(:f_student)
    new_mentor = users(:mentor_5)
    group.update_members(group.mentors + [new_mentor], group.students + [new_student])
    assert_equal [student.id, mentor.id], group.initial_student_mentor_pair
  end

  def test_send_group_change_expiry_date_mails
    group = groups(:mygroup)
    group.mentors << users(:ram)
    member_ids = group.members.pluck(:id)
    assert_difference "PendingNotification.count", member_ids.size do
      Group.send_group_change_expiry_date_mails(group.id, member_ids)
    end
    # newly added member should not be counted for notification
    group.students << users(:f_mentor_student)
    assert_difference "PendingNotification.count", member_ids.size do
      Group.send_group_change_expiry_date_mails(group.id, member_ids)
    end
    # deleted member should not be counted
    group.mentors.last.destroy
    assert_difference "PendingNotification.count", member_ids.size-1 do
      Group.send_group_change_expiry_date_mails(group.id, member_ids)
    end
  end

  def test_reached_critical_mass
    group = groups(:group_pbe_0)
    assert group.pending?
    assert_false group.reached_critical_mass?

    group.update_column(:pending_at, 5.days.ago)
    assert_false group.reached_critical_mass?

    group.stubs(:membership_roles).returns(group.program.roles.for_mentoring)
    assert_false group.reached_critical_mass?

    group.update_column(:pending_at, 7.days.ago)
    assert group.reached_critical_mass?
  end

  def test_meetings_activity_for_all_roles
    group = groups(:mygroup)
    program = group.program
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    meetings_activity = group.meetings_activity_for_all_roles
    meetings_activity_v1 = group.membership_roles.collect { |role| { role.name => group.meetings_activity(role.id)[:role] } }
    assert_equal_hash( { RoleConstants::MENTOR_NAME => mentor_role.id, RoleConstants::STUDENT_NAME => student_role.id }, group.instance_variable_get(:'@roles_for_mentoring_hash'))
    assert_equal_unordered meetings_activity_v1, meetings_activity
  end

  def test_has_future_start_date
    group = groups(:group_pbe_0)
    program = group.program

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    assert program.allow_circle_start_date?
    assert_nil group.start_date

    assert_false group.has_future_start_date?

    group.update_attributes!(start_date: current_time.beginning_of_day - 2.hours)
    assert_false group.has_future_start_date?

    group.update_attributes!(start_date: current_time)
    assert_false group.has_future_start_date?

    group.update_attributes!(start_date: current_time.end_of_day + 1.hour)
    assert group.has_future_start_date?

    program.update_attributes!(allow_circle_start_date: false)
    assert_false group.has_future_start_date?
  end

  def test_has_past_start_date
    group = groups(:group_pbe_0)
    program = group.program

    current_time = Time.now
    Time.stubs(:now).returns(current_time)

    assert program.allow_circle_start_date?
    assert_nil group.start_date

    assert_false group.has_past_start_date?(members(:f_admin))

    group.update_attributes!(start_date: current_time + 14.hours)
    assert_false group.has_past_start_date?(members(:f_admin))

    group.update_attributes!(start_date: current_time + 12.hours)
    assert group.has_past_start_date?(members(:f_admin))

    program.update_attributes!(allow_circle_start_date: false)
    assert_false group.has_past_start_date?(members(:f_admin))
  end

  def test_get_connections_widget_milestones
    group = groups(:mygroup)
    user = users(:f_mentor)
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    milestone3 = create_mentoring_model_milestone

    task1 = create_mentoring_model_task(milestone_id: milestone1.id, required: true, due_date: Date.today + 3.days)
    task2 = create_mentoring_model_task(milestone_id: milestone2.id, required: true, due_date: Date.today - 5.days)
    task3 = create_mentoring_model_task(milestone_id: milestone3.id, required: true, due_date: Date.today + 15.days)
    milestones = [milestone1, milestone2, milestone3]
    assert_equal_unordered [milestone1, milestone2], group.get_connections_widget_milestones(milestones, user)
    task1.update_column(:due_date, Time.now + 15.days)
    task2.update_column(:due_date, Time.now + 15.days)
    assert_equal [], group.get_connections_widget_milestones(milestones, user)
    task3.update_column(:due_date, Time.now - 15.days)
    assert_equal [milestone3], group.get_connections_widget_milestones(milestones, user)
  end

  def test_get_homepage_connection_widget_tasks
    group = groups(:mygroup)
    user = users(:f_mentor)

    task1 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days)
    task2 = create_mentoring_model_task(required: true, due_date: Date.today - 5.days)
    task3 = create_mentoring_model_task(required: true, due_date: Date.today + 15.days)
    task4 = create_mentoring_model_task(user: users(:mkr_student))
    task5 = create_mentoring_model_task(required: true, due_date: 1.day.ago, status: MentoringModel::Task::Status::DONE)

    assert_equal_unordered [task1, task2], group.get_homepage_connection_widget_tasks(user)
    task1.update_column(:due_date, Time.now + 15.days)
    task2.update_column(:due_date, Time.now + 15.days)
    assert_equal [], group.get_homepage_connection_widget_tasks(user)
    task3.update_column(:due_date, Time.now - 15.days)
    assert_equal [task3], group.get_homepage_connection_widget_tasks(user)

    tasks = MentoringModel::Task.where(id: [task1.id, task2.id])
    assert_equal [], group.get_homepage_connection_widget_tasks(user, tasks: tasks)
    task1.update_column(:due_date, Time.now - 15.days)
    assert_equal [task1], group.get_homepage_connection_widget_tasks(user, tasks: tasks)
  end

  def test_get_recent_and_upcoming_pending_tasks
    group = groups(:mygroup)
    user = users(:f_mentor)

    task1 = create_mentoring_model_task(required: true, due_date: Date.today + 3.days)
    task2 = create_mentoring_model_task(required: true, due_date: Date.today - 5.days)
    task3 = create_mentoring_model_task(required: true, due_date: Date.today + 15.days)
    task4 = create_mentoring_model_task(user: users(:mkr_student))
    task5 = create_mentoring_model_task(required: true, due_date: 1.day.ago, status: MentoringModel::Task::Status::DONE)

    assert_equal_unordered [task1, task2], group.get_recent_and_upcoming_pending_tasks(user)
    task1.update_column(:due_date, Time.now + 15.days)
    task2.update_column(:due_date, Time.now + 15.days)
    assert_equal [], group.get_recent_and_upcoming_pending_tasks(user)
  end

  def test_pending_notifications_should_dependent_destroy_on_group_deletion
    group = groups(:mygroup)
    user = users(:f_mentor)
    #Testing has_many association
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::GROUP_MEMBER_LEAVING, RecentActivityConstants::Type::GROUP_MEMBER_UPDATE]
    assert_difference "PendingNotification.count", 2 do
      action_types.each do |action_type|
        pending_notifications << group.pending_notifications.create!(
                  ref_obj_creator: user,
                  ref_obj: group,
                  program: group.program,
                  action_type: action_type)
      end
    end
    #Testing dependent destroy
    assert_equal pending_notifications, group.pending_notifications
    assert_difference 'Group.count', -1 do
      assert_difference 'PendingNotification.count', -2 do
        group.destroy
      end
    end
  end

  def test_can_be_reactivated_by_user
    group = groups(:mygroup)
    program = group.program
    user = users(:f_mentor)
    assert_false group.can_be_reactivated_by_user?(nil)
    group.stubs(:closed?).returns(false)
    assert_false group.can_be_reactivated_by_user?(user)
    group.stubs(:closed?).returns(true)
    user.stubs(:can_manage_or_own_group?).returns(true)
    assert group.can_be_reactivated_by_user?(user)
    user.stubs(:can_manage_or_own_group?).returns(false)
    program.stubs(:has_role_permission?).with("mentor", "reactivate_groups").returns(true)
    program.stubs(:has_role_permission?).with("student", "reactivate_groups").returns(false)
    assert group.can_be_reactivated_by_user?(user)
    assert_false group.can_be_reactivated_by_user?(users(:mkr_student))
    program.stubs(:has_role_permission?).with("mentor", "reactivate_groups").returns(false)
    assert_false group.can_be_reactivated_by_user?(user)
  end

  def test_has_teacher
    assert groups(:rejected_group_1).has_teacher?(users(:pbe_teacher_0))
    assert_false groups(:rejected_group_1).has_teacher?(users(:pbe_teacher_1))
  end

  def test_open_or_proposed
    group = Group.first
    group.stubs(:open?).returns(true)
    group.stubs(:proposed?).returns(true)
    assert group.open_or_proposed?
    group.stubs(:proposed?).returns(false)
    assert group.open_or_proposed?
    group.stubs(:open?).returns(false)
    assert_false group.open_or_proposed?
  end

  def test_get_user_id_role_id_hash
    group = Group.first
    user_id_role_id_hash = {}
    group.memberships.each do |membership|
      user_id_role_id_hash[membership.user_id] = membership.role_id
    end
    assert_equal user_id_role_id_hash, group.get_user_id_role_id_hash
  end

  def test_available_roles_for_user_to_join
    user = users(:f_student_pbe)
    group = groups(:group_pbe)
    role = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME)
    group.expects(:available_roles_for_joining).with(user.role_ids).returns([role]).twice
    assert_equal [role], group.available_roles_for_user_to_join(user)
    role.update_column(:max_connections_limit, 0)
    assert_empty group.available_roles_for_user_to_join(user)
  end

  private

  def create_task_with_creator(group, creator, created_at)
    t = Task.new(:group => group, :due_date => 2.days.from_now.to_date,
      :title => "Some title", :student => group.students.first,
      :created_at => created_at)
    t.saver = creator
    t.save!
    return t
  end
end