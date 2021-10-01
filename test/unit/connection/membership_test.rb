require_relative './../../test_helper.rb'

class Connection::MembershipTest < ActiveSupport::TestCase
  def test_create_success
    user = users(:student_5)
    membership = nil
    assert_difference 'Connection::Membership.count' do
      membership = Connection::Membership.create!(
        :group => groups(:mygroup),
        :user => user,
        :status => Connection::Membership::Status::ACTIVE,
        :role_id => user.roles.find_by(name: RoleConstants::STUDENT_NAME).id
      )
    end
    assert Connection::Membership.last.api_token.present?
  end

  def test_observers_reindex_es
    user = users(:student_5)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(3).with(User, [9, 3, 15])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Group, [1]).times(3)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(User, [15]).times(4)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).twice.with(Member, [user.member_id])
    membership = Connection::Membership.create!(
      group: groups(:mygroup),
      user: user,
      status: Connection::Membership::Status::ACTIVE,
      role_id: user.roles.find_by(name: RoleConstants::STUDENT_NAME).id
    )
    membership.update_attribute(:status, Connection::Membership::Status::INACTIVE)
    membership.destroy
  end

  def test_presence_of_group_and_user
    assert_no_difference 'Connection::Membership.count' do
      assert_multiple_errors([{:field => :group}, {:field => :role_id}, {:field => :user}]) do
        Connection::Membership.create!
      end
    end
  end

  def test_group_and_user_belong_to_same_program
    assert_no_difference 'Connection::Membership.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :user, "doesn't belong to the program" do
        Connection::Membership.create!(
          :user => users(:psg_mentor),
          :group => groups(:mygroup)
        )
      end
    end
  end

  def test_validates_uniqueness_of_group_and_user
    group = groups(:mygroup)
    user = users(:f_mentor)
    user.add_role(RoleConstants::STUDENT_NAME)

    assert Connection::Membership.exists?(
      group_id: group,
      user_id: user,
      status: Connection::Membership::Status::ACTIVE)

    assert_no_difference 'Connection::Membership.count' do
      assert_raise ActiveRecord::RecordInvalid, "The user Good unique name is already part of the connection as 'Mentor' and cannot be assigned 'Student' role unless removed from the connection first." do
        Connection::Membership.create!(group: group, user: user, role: group.program.roles.find_by(name: RoleConstants::STUDENT_NAME), status: Connection::Membership::Status::ACTIVE)
      end
    end
  end

  def test_validates_presence_of_api_token
    cm =  Connection::Membership.first

    assert_no_difference 'Connection::Membership.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :api_token) do
        cm.update_attributes!(:api_token => nil)
      end
    end
  end

  def test_validates_uniqueness_of_api_token
    cm_1 =  Connection::Membership.first
    cm_2 =  Connection::Membership.last

    assert_false(cm_1.id == cm_2.id)

    assert_raise_error_on_field(ActiveRecord::RecordInvalid, :api_token) do
      cm_2.update_attributes!(:api_token => cm_1.api_token)
    end
  end

  def test_validate_status
    assert_no_difference 'Connection::Membership.count' do
      assert_raise_error_on_field(ActiveRecord::RecordInvalid, :status) do
        Connection::Membership.create!(
          :group => groups(:mygroup),
          :user => users(:mentor_4),
          :status => 100)
      end
    end
  end

  def test_of_scope
    membership_1 = fetch_connection_membership(:mentor, groups(:mygroup))
    assert_equal [membership_1], Connection::Membership.of(users(:f_mentor))

    g_1 = create_group(:mentors => [users(:mentor_3)], :students => [users(:student_3)])
    assert_equal g_1.mentor_memberships, Connection::Membership.of(users(:mentor_3))

    g_2 = create_group(:mentors => groups(:mygroup).mentors, :students => [users(:student_5)])
    membership_3 = g_2.mentor_memberships.first

    assert_equal [membership_1, membership_3], Connection::Membership.of(users(:f_mentor))
  end

  def test_notified_on_status_from_active_to_inactivity_notified
    group = groups(:mygroup)
    user = group.mentor_memberships.first.user
    membership = fetch_connection_membership(:mentor, group)
    activity = RecentActivity.create!(
      :action_type => RecentActivityConstants::Type::VISIT_MENTORING_AREA,
      :member_id => user.member.id,
      :ref_obj => group,
      :target => RecentActivityConstants::Target::NONE,
      :programs => [user.program]
    )
    assert_emails do
      membership.status = Connection::Membership::Status::INACTIVE
      membership.save!
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_mentor).email], email.to
    assert_match activity.created_at.strftime("%B %d, %Y"), get_html_part_from(email)
  end

  def test_has_many_private_notes
    assert_equal [
        connection_private_notes(:mygroup_mentor_1),
        connection_private_notes(:mygroup_mentor_2)],
      fetch_connection_membership(:mentor, groups(:mygroup)).private_notes

    assert_equal [connection_private_notes(:group_2_student_1)],
      fetch_connection_membership(:student, Group.all[1]).private_notes

    assert_equal [], fetch_connection_membership(:mentor, Group.all[1]).private_notes

    # Dependent destroy of private notes
    mem = fetch_connection_membership(:mentor, groups(:mygroup))
    g = mem.group
    mentors = ([users(:mentor_3)] + g.mentors)
    students = g.students
    assert !g.has_mentor?(users(:mentor_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))
    assert_difference 'Connection::Membership.count', -1 do
      assert_difference 'Connection::PrivateNote.count', -2 do
        fetch_connection_membership(:mentor, groups(:mygroup)).destroy
      end
    end
  end

  def test_has_many_mentoring_model_tasks
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    5.times do
      create_mentoring_model_task
    end

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

    # Task should not be dependent destroyed
    assert_difference 'Connection::Membership.count', -1 do
      assert_no_difference 'MentoringModel::Task.count' do
        mem1.destroy
      end
    end

    assert_equal ([nil] * 5), g.reload.mentoring_model_tasks.collect(&:user)
  end

  def test_pending_notifications_should_dependent_destroy_on_membership_deletion
    group = groups(:multi_group)
    membership = group.memberships.first
    #Testing has_many association
    pending_notifications = []
    action_types = [RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION, RecentActivityConstants::Type::ADMIN_MESSAGE_NOTIFICATION]
    assert_difference "PendingNotification.count", 2 do
      action_types.each do |action_type|
        pending_notifications << membership.pending_notification_references.create!(
                  ref_obj_creator: membership.user,
                  ref_obj: membership,
                  program: group.program,
                  action_type: action_type)
      end
    end
    #Testing dependent destroy
    assert_equal pending_notifications, membership.pending_notification_references
    assert_difference 'Connection::Membership.count', -1 do
      assert_difference 'PendingNotification.count', -2 do
        membership.destroy
      end
    end
  end

  def test_has_many_job_logs
    group = groups(:multi_group)
    membership = group.memberships.first
    assert_difference "JobLog.count", 1 do
      membership.job_logs.create!(job_uuid: JobLog.generate_uuid)
    end

    assert_difference "JobLog.count", -1 do
      membership.destroy
    end
  end

  def test_destroy_membership_nullify_connection_membership_ids_for_tasks
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    5.times do
      create_mentoring_model_task
    end

    #adding one more mentor so that we can destroy mentor membership
    assert g.has_mentor?(users(:f_mentor))
    assert g.has_mentee?(users(:mkr_student))
    mentors = ([users(:mentor_3)] + g.mentors)
    students = g.students
    assert !g.has_mentor?(users(:mentor_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))

    mem1 = g.membership_of(users(:f_mentor))
    assert_equal 5, mem1.mentoring_model_tasks.size

    mentoring_model_tasks_ids = mem1.mentoring_model_tasks.collect(&:id)
    # Task should not be dependent destroyed
    assert_difference 'Connection::Membership.count', -1 do
      assert_no_difference 'MentoringModel::Task.count' do
        mem1.destroy
      end
    end

    assert_equal ([nil] * 5),  MentoringModel::Task.where(:id => mentoring_model_tasks_ids).collect(&:connection_membership_id)
  end

  def test_destroy_membership_NOT_nullify_connection_membership_ids_for_tasks
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)

    5.times do
      create_mentoring_model_task
    end

    #adding one more mentor so that we can destroy mentor membership
    assert g.has_mentor?(users(:f_mentor))
    assert g.has_mentee?(users(:mkr_student))
    mentors = ([users(:mentor_3)] + g.mentors)
    students = g.students
    assert !g.has_mentor?(users(:mentor_3))
    g.update_members(mentors, students)
    g.reload
    assert g.has_mentor?(users(:mentor_3))

    mem1 = g.membership_of(users(:f_mentor))
    assert_equal 5, mem1.mentoring_model_tasks.size

    connection_membership_ids = mem1.mentoring_model_tasks.collect(&:connection_membership_id)
    mentoring_model_tasks_ids = mem1.mentoring_model_tasks.collect(&:id)
    #For custom members destroy we don't want connection member ids to be nullified
    mem1.handle_custom_members_update = true
    # Task should not be dependent destroyed
    assert_difference 'Connection::Membership.count', -1 do
      assert_no_difference 'MentoringModel::Task.count' do
        mem1.destroy
      end
    end

    assert_equal connection_membership_ids,  MentoringModel::Task.where(:id => mentoring_model_tasks_ids).collect(&:connection_membership_id)
  end

  def test_handle_reply_via_email_success
    scrap_msg = "Sample scrap message"
    cm = fetch_connection_membership(:mentor, groups(:mygroup))
    assert_difference "Scrap.count" do
      assert_emails 1 do
        assert cm.handle_reply_via_email(content: scrap_msg)
      end
    end

    scrap = Scrap.last
    assert_equal 1, scrap.receivers.count
    assert_equal scrap_msg, scrap.content
    assert scrap.posted_via_email
  end

  def test_handle_reply_via_email_failure
    scrap_msg = "Sample scrap message"
    cm = fetch_connection_membership(:mentor, groups(:mygroup))
    Group.any_instance.expects(:active?).returns(false)
    ChronusMailer.expects(:posting_in_mentoring_area_failure).once
    NilClass.any_instance.expects(:deliver_now).once
    assert_no_difference "Scrap.count" do
      assert_false cm.handle_reply_via_email(content: scrap_msg)
    end
  end

  def test_increment_login_count
    cm = fetch_connection_membership(:mentor, groups(:mygroup))

    assert_equal 0, cm.login_count
    cm.increment_login_count
    assert_equal 1, cm.reload.login_count
  end

  def test_destroy_dependent_objects
    group = groups(:mygroup)
    membership = group.memberships.where(user_id: users(:f_mentor).id).first
    tasks = []
    3.times do |iterator|
      tasks[iterator] = create_mentoring_model_task
    end
    Connection::Membership.destroy_dependent_objects(group.id, [membership.id], [])
    3.times do |iterator|
      task = tasks[iterator]
      assert_nil task.reload.user
      assert_false task.connection_membership_id?
      assert_false task.from_template?
      assert_false task.unassigned_from_template?
    end
  end

  def test_validation_role_id
    group = groups(:mygroup)
    connection_membership = group.memberships.new
    assert_false connection_membership.valid?
    assert_equal ["can't be blank"], connection_membership.errors[:role_id]
  end

  def test_belongs_to_role
    program = programs(:albers)
    mentor_membership = program.connection_memberships.where(type: Connection::MentorMembership).first
    assert_equal program.roles.find_by!(name: RoleConstants::MENTOR_NAME), mentor_membership.role

    program = programs(:albers)
    mentee_membership = program.connection_memberships.where(type: Connection::MenteeMembership).first
    assert_equal program.roles.find_by!(name: RoleConstants::STUDENT_NAME), mentee_membership.role
  end

  def test_before_validation_callback
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    group = create_group(
      program: program,
      mentors: [users(:mentor_3), users(:mentor_4)],
      students: [users(:student_4), users(:student_5)],
      notes: "This is a test group"
    )
    assert_equal 2, group.mentors.size
    assert_equal 2, group.students.size

    roles_hash = program.roles.group_by(&:name)
    mentor_role_id = roles_hash[RoleConstants::MENTOR_NAME].first.id
    student_role_id = roles_hash[RoleConstants::STUDENT_NAME].first.id

    assert_equal ([student_role_id] * 2 + [mentor_role_id] * 2), group.memberships.pluck(:role_id)
  end

  def test_validate_for_mentoring
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    group = create_group(
      program: program,
      mentors: [users(:mentor_3), users(:mentor_4)],
      students: [users(:student_4), users(:student_5)],
      notes: "This is a test group"
    )
    mentor_membership = group.mentor_memberships.first
    mentor_membership.role_id = program.roles.find_by(name: RoleConstants::ADMIN_NAME).id
    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Admin cannot be part of Mentoring Connection" do
      mentor_membership.save!
    end
  end

  def test_validate_only_one_user_for_a_group
    program = programs(:albers)
    allow_one_to_many_mentoring_for_program(program)
    group = create_group(
      program: program,
      mentors: [users(:mentor_3), users(:mentor_4)],
      students: [users(:student_4), users(:student_5)],
      notes: "This is a test group"
    )

    teacher_role = create_role(name: "teacher", for_mentoring: true)
    user = users(:mentor_3)
    user.roles += [teacher_role]
    user.save!
    assert_equal [], group.custom_memberships
    assert_equal [], group.custom_users

    assert_raise ActiveRecord::RecordInvalid, "Validation failed: User has already been taken" do
      membership = group.custom_memberships.create!(
        user: user,
        role: teacher_role
      )
    end
  end

  def test_update_membership_role
    user = users(:f_mentor_student)
    group = groups(:mygroup)
    roles = user.program.get_roles([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
    membership = group.memberships.find_or_initialize_by(user_id: user.id)

    assert membership.update_role!(roles[0])
    assert_equal roles[0], membership.role
    assert_equal Connection::MentorMembership.name ,membership.type

    assert membership.update_role!(roles[1])
    assert_equal roles[1], membership.role
    assert_equal Connection::MenteeMembership.name ,membership.type
  end

  def test_create_user_state_change_on_group_state_change
    group = create_group(:mentors => [users(:mentor_6)], :students => [users(:student_6)])
    member1 = group.memberships.first
    member2 = group.memberships.last

    user_1 = member1.user
    user_1_info = {
      from_state: user_1.state,
      to_state: user_1.state,
      role_ids: user_1.role_ids,
      role_ids_in_active_groups: user_1.role_ids_in_active_groups
    }

    assert_no_difference 'UserStateChange.count' do
      member1.create_user_state_change_on_group_state_change(Time.now, {group: {from_state: nil, to_state: Group::Status::ACTIVE}, user: user_1_info})
    end
    assert_no_difference 'UserStateChange.count' do
      member1.create_user_state_change_on_group_state_change(Time.now, {group: {from_state: Group::Status::DRAFTED, to_state: Group::Status::CLOSED}, user: user_1_info})
    end
    assert_no_difference 'UserStateChange.count' do
      member1.create_user_state_change_on_group_state_change(Time.now, {group: {from_state: Group::Status::ACTIVE, to_state: Group::Status::INACTIVE}, user: user_1_info})
    end
    assert_no_difference 'UserStateChange.count' do
      member1.create_user_state_change_on_group_state_change(Time.now, {group: {from_state: Group::Status::ACTIVE, to_state: Group::Status::ACTIVE}, user: user_1_info})
    end
    member_1_roles = group.memberships.first.user.connection_memberships.of_active_criteria_groups.collect(&:role_id)
    member_2_roles = group.memberships.last.user.connection_memberships.of_active_criteria_groups.collect(&:role_id)
    assert_difference 'UserStateChange.count', 2 do
      group.update_attribute(:status , Group::Status::DRAFTED)
    end
    member_1_from_roles = Array.new(member_1_roles)
    member_2_from_roles = Array.new(member_2_roles)
    member_1_roles.delete_at(member_1_roles.index(group.memberships.first.role_id))
    member_2_roles.delete_at(member_2_roles.index(group.memberships.last.role_id))
    assert_equal member_1_from_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_1_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["to_role"]
    assert_equal member_2_from_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_2_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    assert_difference 'UserStateChange.count', 2 do
      group.update_attribute(:status , Group::Status::ACTIVE)
    end
    assert_equal member_1_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_1_from_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["to_role"]
    assert_equal member_2_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_2_from_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    assert_no_difference 'UserStateChange.count' do
      group.update_attribute(:status , Group::Status::INACTIVE)
    end

    assert_difference 'UserStateChange.count', 2 do
      group.update_attribute(:status , Group::Status::DRAFTED)
    end
    assert_equal member_1_from_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_1_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["to_role"]
    assert_equal member_2_from_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_2_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    assert_difference 'UserStateChange.count', 2 do
      group.update_attribute(:status , Group::Status::INACTIVE)
    end
    assert_equal member_1_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_1_from_roles.uniq, UserStateChange.last(2).first.connection_membership_info_hash["role"]["to_role"]
    assert_equal member_2_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal member_2_from_roles.uniq, UserStateChange.last.connection_membership_info_hash["role"]["to_role"]
  end

  def test_create_user_state_change_on_connection_membership_change
    allow_one_to_many_mentoring_for_program(programs(:albers))
    group = create_group(:mentors => [users(:mentor_6)], :students => [users(:student_6), users(:student_5)])
    mentor = group.mentors.first
    date_id = Time.now.utc.to_i/1.day.to_i
    student6_role = users(:student_6).connection_memberships.first.role_id
    assert_difference 'UserStateChange.count', 1 do
      users(:student_6).connection_memberships.first.destroy
    end
    assert_equal [student6_role], UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal [], UserStateChange.last.connection_membership_info_hash["role"]["to_role"]
    group = group.reload
    assert_difference 'UserStateChange.count', 1 do
      group.update_members([users(:mentor_6)], [users(:student_5), users(:student_6)])
    end
    assert_equal [], UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal [student6_role], UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    membership = users(:student_6).connection_memberships.last
    assert_difference 'UserStateChange.count', 1 do
      membership.create_user_state_change_on_connection_membership_change(date_id, user_group_membership_info_hash_for_state_changes(membership, Connection::Membership::Status::ACTIVE, nil))
    end
    assert_equal [student6_role], UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal [], UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    group.update_attribute(:status, Group::Status::INACTIVE)
    assert_difference 'UserStateChange.count', 1 do
      membership.reload.create_user_state_change_on_connection_membership_change(date_id, user_group_membership_info_hash_for_state_changes(membership, nil, Connection::Membership::Status::ACTIVE))
    end
    assert_equal [], UserStateChange.last.connection_membership_info_hash["role"]["from_role"]
    assert_equal [student6_role], UserStateChange.last.connection_membership_info_hash["role"]["to_role"]

    group.update_attribute(:status, Group::Status::DRAFTED)
    assert_no_difference 'UserStateChange.count' do
      membership.reload.create_user_state_change_on_connection_membership_change(date_id, user_group_membership_info_hash_for_state_changes(membership, Connection::Membership::Status::ACTIVE, nil))
    end
  end

  def test_of_active_criteria_groups_scope
    assert_equal_unordered Group.where("groups.status IN (?)", Group::Status::ACTIVE_CRITERIA).collect(&:memberships).flatten.collect(&:id), Connection::Membership.of_active_criteria_groups.pluck(:id)
  end

  def test_get_last_outstanding_survey_task
    group = groups(:group_2)
    cm = group.memberships.first
    assert_nil cm.get_last_outstanding_survey_task

    mentoring_model = programs(:albers).mentoring_models.default.first
    group.update_attribute(:mentoring_model_id, mentoring_model.id)
    assert_nil cm.get_last_outstanding_survey_task

    survey = surveys(:progress_report)
    task_template = create_mentoring_model_task_template
    task_template.action_item_type = MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
    task_template.action_item_id = survey.id
    task_template.skip_survey_validations = true
    task_template.save!
    task1 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, mentoring_model_task_template_id: task_template.id, connection_membership_id: cm.id, due_date: Time.now+1.day)
    task2 = create_mentoring_model_task(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, action_item_id: survey.id, mentoring_model_task_template_id: task_template.id, connection_membership_id: cm.id, due_date: Time.now+2.days)

    cm.reload

    assert_false task1.overdue?

    assert_nil cm.get_last_outstanding_survey_task

    MentoringModel::Task.any_instance.stubs(:overdue?).returns(true)
    assert task1.overdue?
    assert_equal task1, cm.get_last_outstanding_survey_task
  end

  def test_active_inactive
    assert connection_memberships(:connection_memberships_1).active?
    assert_false connection_memberships(:connection_memberships_1).inactive?
    connection_memberships(:connection_memberships_1).update_attributes!(status: Connection::Membership::Status::INACTIVE)
    assert connection_memberships(:connection_memberships_1).inactive?
    assert_false connection_memberships(:connection_memberships_1).active?
  end

  def test_send_email
    object = users(:f_mentor)
    action_type = RecentActivityConstants::Type::GROUP_MEMBER_UPDATE
    ChronusMailer.expects(:group_conversation_creation_notification).never
    assert_difference "PendingNotification.count", 1 do
      connection_memberships(:connection_memberships_1).send_email(object, action_type, nil, nil, {})
    end
    pending_notification = PendingNotification.last
    assert_equal object, pending_notification.ref_obj
    assert_equal connection_memberships(:connection_memberships_1), pending_notification.ref_obj_creator
    assert_equal action_type, pending_notification.action_type

    connection_membership = connection_memberships(:connection_memberships_1)
    create_topic(title: "Topic Title")
    object = Topic.last
    ChronusMailer.expects(:group_conversation_creation_notification).with(connection_membership.user, object, {sender: object.user}).once.returns(stub(:deliver_now))
    connection_membership.send_email(object, object.class.recent_activity_type)
  end

  def test_target_user_type_and_target_user_id
    membership = connection_memberships(:connection_memberships_1)
    assert_nil membership.target_user_type
    assert_nil membership.target_user_id
    membership.update_attributes!(last_applied_task_filter: {user_info: GroupsController::TargetUserType::ALL_MEMBERS})
    assert_equal GroupsController::TargetUserType::ALL_MEMBERS, membership.target_user_type
    assert_nil membership.target_user_id
    membership.update_attributes!(last_applied_task_filter: {user_info: GroupsController::TargetUserType::UNASSIGNED})
    assert_equal GroupsController::TargetUserType::UNASSIGNED, membership.target_user_type
    assert_nil membership.target_user_id
    membership.update_attributes!(last_applied_task_filter: {user_info: "3"})
    assert_equal GroupsController::TargetUserType::INDIVIDUAL, membership.target_user_type
    assert_equal 3, membership.target_user_id
    #If the connection membership contains the user id of a removed user
    membership.update_attributes!(last_applied_task_filter: {user_info: "2"})
    assert_nil membership.target_user_type
    assert_nil membership.target_user_id
  end

  def test_user_ids_in_groups
    program = programs(:albers)
    pbe = programs(:pbe)
    assert_equal [], Connection::Membership.user_ids_in_groups([], program, nil)
    assert_equal [], Connection::Membership.user_ids_in_groups(pbe.groups.pluck(:id), program, nil)
    assert_equal_unordered program.groups.collect(&:members).flatten.collect(&:id).uniq, Connection::Membership.user_ids_in_groups(program.groups.pluck(:id), program, nil)
    assert_equal_unordered program.groups.collect(&:mentors).flatten.collect(&:id).uniq, Connection::Membership.user_ids_in_groups(program.groups.pluck(:id), program, RoleConstants::MENTOR_NAME)
    assert_equal_unordered program.groups.collect(&:students).flatten.collect(&:id).uniq, Connection::Membership.user_ids_in_groups(program.groups.pluck(:id), program, RoleConstants::STUDENT_NAME)

    group = groups(:mygroup)
    assert_equal_unordered group.members.pluck(:id), Connection::Membership.user_ids_in_groups([group.id], program, Connection::Membership::SendMessage::ALL)
    assert_equal_unordered group.students.pluck(:id), Connection::Membership.user_ids_in_groups([group.id], program, RoleConstants::STUDENT_NAME)
    assert_equal [], Connection::Membership.user_ids_in_groups([group.id], program, Connection::Membership::SendMessage::OWNER)

    cm = group.memberships.first
    cm.update_attribute(:owner, true)
    assert_equal [cm.user_id], Connection::Membership.user_ids_in_groups([group.id], program, Connection::Membership::SendMessage::OWNER)

    group = pbe.groups.first
    cm = group.memberships.first
    third_role = pbe.find_role(RoleConstants::TEACHER_NAME)
    cm.update_attribute(:role_id, third_role.id)
    assert_equal [cm.user_id], Connection::Membership.user_ids_in_groups([group.id], pbe, RoleConstants::TEACHER_NAME)
  end

  def test_validates_view_mode
    membership = connection_memberships(:connection_memberships_1)
    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Last applied task filter view mode is invalid" do
      membership.update_attributes!(last_applied_task_filter: {user_info: GroupsController::TargetUserType::ALL_MEMBERS, view_mode: "3"})
    end
  end

  def test_of_open_or_proposed_group
    membership = Connection::Membership.joins(:group).where(groups: {status: [Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::PROPOSED]}).first
    assert membership.of_open_or_proposed_group?
    membership = Connection::Membership.joins(:group).where.not(groups: {status: [Group::Status::ACTIVE, Group::Status::INACTIVE, Group::Status::PROPOSED]}).first
    assert_false membership.of_open_or_proposed_group?
  end

  def test_with_role
    membership = Connection::Membership.first
    role = membership.role
    assert membership.with_role?(role)
    assert_false membership.with_role?(Role.where.not(id: role.id).first)
  end

  private

  def user_group_membership_info_hash_for_state_changes(membership, membership_from_state, membership_to_state)
    user = membership.user
    info = {
      user: {from_state: user.state, to_state: user.state, role_ids: user.role_ids, role_ids_in_active_groups: user.role_ids_in_active_groups},
      group: {state: membership.group.status},
      connection_membership: {from_state: membership_from_state, to_state: membership_to_state}
    }
    info
  end
end