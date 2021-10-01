require_relative './../../test_helper.rb'

class GroupObserverTest < ActiveSupport::TestCase
  include ApplicationHelper

  def setup
    super
    # Required for testing mails
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_after_update
    g = groups(:mygroup)
    Group.expects(:remove_upcoming_meetings_of_group).with(g.id).once

    # Terminate the group
    Group.expects(:send_group_termination_notification).once
    g.terminate!(users(:f_admin), "Test reason", g.program.permitted_closure_reasons.first.id)

    # Reactivate the group
    Group.expects(:send_group_reactivation_mails).once
    g.change_expiry_date(users(:f_admin), Time.now + 2.months, "Test Reason")


    # Change Expiry Date of the group
    assert_difference('RecentActivity.count') do
      assert_pending_notifications 2 do
        g.change_expiry_date(users(:f_admin), Time.now + 3.months, "Test Reason new")
      end
    end

    assert_equal RecentActivityConstants::Type::GROUP_CHANGE_EXPIRY_DATE, RecentActivity.last.action_type

    allow_one_to_many_mentoring_for_program(programs(:albers))
    assert programs(:albers).reload.allow_one_to_many_mentoring?
    users(:f_mentor).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:f_mentor).max_connections_limit
    users(:mentor_3).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:mentor_3).max_connections_limit
    users(:pending_user).update_attribute(:max_connections_limit, 5)
    assert_equal 5, users(:pending_user).max_connections_limit

    # Add Mentor
    self.stubs(:current_user).returns(users(:f_admin))
    mentors = [users(:mentor_3)] + g.mentors
    students = g.students
    g.update_members(mentors, students, users(:f_admin))
    assert g.has_mentor?(users(:mentor_3))

    # Add Mentee
    mentors = g.mentors
    students = [users(:student_3)] + g.students
    g.update_members(mentors, students, users(:f_admin))
    assert g.has_mentee?(users(:student_3))

    # Add 2 Mentees
    mentors = g.mentors
    students = [users(:student_4), users(:student_5)] + g.students
    g.update_members(mentors, students, users(:f_admin))
    assert g.has_mentee?(users(:student_4))
    assert g.has_mentee?(users(:student_5))

    # Mentoring Offer
    student6 = users(:student_6)
    mentor1 = g.mentors.first
    g.offered_to = student6
    g.actor = mentor1
    g.update_members(g.mentors, g.students + [student6], g.actor)
    assert g.has_mentee?(student6)

    # Add Inactive Mentor
    mentors = [users(:pending_user)] + g.mentors
    students = g.students
    g.update_members(mentors, students, users(:f_admin))
    assert users(:pending_user).state == User::Status::ACTIVE
    assert g.has_mentor?(users(:pending_user))
  end

  def test_track_state_changes
    Timecop.freeze do
      group = nil
      assert_difference("GroupStateChange.count") do
        group = create_group
      end
      check_group_state_change_unit(group, GroupStateChange.last, nil)
      [Group::Status::INACTIVE, Group::Status::ACTIVE].each do |status|
        from_status = group.status
        group.status = status
        assert_difference("GroupStateChange.count") do
          assert_difference "ConnectionMembershipStateChange.count", group.memberships.count do
            group.save!
          end
          assert_equal from_status, ConnectionMembershipStateChange.last.info_hash[:group][:from_state]
          assert_equal group.status, ConnectionMembershipStateChange.last.info_hash[:group][:to_state]
        end
        check_group_state_change_unit(group, GroupStateChange.last, from_status)
      end
    end
  end

  def test_after_update_for_leave_connection
    g = groups(:mygroup)
    program = g.program
    program.update_attributes(:allow_users_to_leave_connection => true)
    #Creating RA for 'many' scenario

    user = g.members.first
    Group.expects(:send_group_termination_notification)
    assert_difference('RecentActivity.count') do
      g.actor= user
      g.termination_reason = "I am done."
      g.terminate!(user, g.termination_reason, g.program.permitted_closure_reasons.first.id, Group::TerminationMode::LEAVING)
      assert_equal(RecentActivity.last.action_type, RecentActivityConstants::Type::GROUP_TERMINATING)
    end
  end

  def test_before_create
    p = programs(:albers)
    mentoring_period = 120.days
    p.update_attribute(:mentoring_period, mentoring_period)
    assert_equal mentoring_period, p.mentoring_period
    g = create_group(:mentor => users(:f_mentor_student), :students => [users(:f_student)], :program => p)
    assert_time_string_equal mentoring_period.from_now.to_date.end_of_day, g.expiry_time
  end

  def test_before_create_should_withdraw_mentor_requests
    program = programs(:albers)
    # set limits attributes
    program_attributes = {
      max_pending_requests_for_mentee: 2,
      max_connections_for_mentee:      1,
    }
    program.update_attributes!(program_attributes)

    student = users(:f_student)
    mentors = [users(:f_mentor_student), users(:f_mentor)]
    requests = mentors.map do |mentor|
      MentorRequest.create!(program: program, student: student, mentor: mentor, message: "Hi")
    end

    create_group(mentor: mentors[0], students: [student], program: program)
    requests.each(&:reload) # make sure we test actual data
    assert_equal AbstractRequest::Status::WITHDRAWN, requests[0].status
    assert_equal AbstractRequest::Status::WITHDRAWN, requests[1].status
  end

  def test_after_create
    # Mentoring Offer
    Group.any_instance.expects(:create_ra_and_notify_mentee_about_mentoring_offer)
    p= programs(:albers)
    student = users(:student_6)
    mentor = users(:mentor_6)
    g = p.groups.new
    g.mentors = [mentor]
    g.students = [student]
    g.offered_to = student
    g.actor = mentor
    g.save!
  end

  def test_creating_group_with_members_should_create_membership_state_changes
    p = programs(:albers)
    student = users(:student_6)
    mentor = users(:mentor_6)
    assert_difference "ConnectionMembershipStateChange.count", 2 do
      g = p.groups.new
      g.mentors = [mentor]
      g.students = [student]
      g.save!
    end
  end

  def test_before_validation_on_create
    p = programs(:albers)
    mentoring_period = 120.days
    p.update_attribute(:mentoring_period, mentoring_period)
    assert_equal mentoring_period, p.mentoring_period
    g = create_group(:mentor => users(:f_mentor_student), :students => [users(:f_student)], :program => p)
    assert_equal "Studenter & example", g.name
    assert_time_string_equal mentoring_period.from_now.to_date.end_of_day, g.expiry_time
    group = create_group(mentor: [users(:f_mentor_student), users(:f_mentor)], students: [users(:arun_albers)], program: p)
    assert_equal "Studenter, name, & albers", group.name
  end

  def test_before_validation_on_create_drafted_connection
    p = programs(:albers)
    mentoring_period = 120.days
    p.update_attribute(:mentoring_period, mentoring_period)
    assert_equal mentoring_period, p.mentoring_period
    g = create_group(:mentor => users(:f_mentor_student), :students => [users(:f_student)], :program => p, :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    assert g.drafted?
    assert_match "Studenter & example", g.name
    assert_nil g.expiry_time
  end

  def test_update_attribute_skipping_observer
    g = groups(:mygroup)
    assert g.active?
    
    assert_equal 3, members(:f_mentor).ongoing_engagements_count
    assert_equal 0, members(:f_mentor).closed_engagements_count 
    assert_no_emails do
      g.update_attribute_skipping_observer(:status, Group::Status::CLOSED)
      assert_equal 1, members(:f_mentor).reload.closed_engagements_count 
      assert_equal 2, members(:f_mentor).reload.ongoing_engagements_count 
    end
    assert g.reload.closed?

    assert_equal 1, members(:f_mentor).closed_engagements_count 
    assert_equal 2, members(:f_mentor).ongoing_engagements_count
    assert_no_emails do
      g.update_attribute_skipping_observer(:status, Group::Status::ACTIVE)
      assert_equal 3, members(:f_mentor).reload.ongoing_engagements_count
      assert_equal 0, members(:f_mentor).reload.closed_engagements_count 
    end
    assert g.reload.active?

    assert_equal 0, users(:pending_user).member.ongoing_engagements_count 
    g = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:pending_user)], actor: users(:f_admin), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    assert_no_emails do
      g.update_attribute_skipping_observer(:status, Group::Status::ACTIVE)
      assert users(:pending_user).reload.state == User::Status::ACTIVE
      assert_equal 1, users(:pending_user).member.ongoing_engagements_count 
    end
    assert g.reload.active?
  end

  def test_withdraw_mentor_request_on_reaching_mentee_limit_on_adding_new_group
    program = programs(:albers)
    program.update_attributes!(:max_connections_for_mentee => 2)
    program.reload
    mentee = users(:mkr_student)
    assert_equal 0, mentee.sent_mentor_requests.size
    assert_equal 1, mentee.groups.size
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'MentorRequest.count' do
        @mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => mentee, :mentor => users(:ram))
      end
    end
    assert_equal 1, mentee.reload.sent_mentor_requests.size

    assert_difference 'Group.count' do
      assert_no_difference 'RecentActivity.count' do
        create_group(:students => [mentee], :mentors => [users(:mentor_0)], :program => program)
      end
    end
    assert_equal AbstractRequest::Status::WITHDRAWN, mentee.reload.sent_mentor_requests.first.status # mentor request withdrawn
  end

  def test_withdraw_mentor_request_on_reaching_mentee_limit_on_publishing_draft_group
    program = programs(:albers)
    program.update_attributes!(:max_connections_for_mentee => 2)
    program.reload
    mentee = users(:mkr_student)
    assert_equal 0, mentee.sent_mentor_requests.size
    assert_equal 1, mentee.groups.size
    assert_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference 'MentorRequest.count' do
        @mentor_request = MentorRequest.create!(:message => "Hi", :program => programs(:albers), :student => mentee, :mentor => users(:ram))
      end
    end
    assert_equal 1, mentee.reload.sent_mentor_requests.size

    assert_difference 'Group.count' do
      assert_no_difference 'RecentActivity.count' do
        assert_no_emails do
          create_group(:students => [mentee], :mentors => [users(:mentor_0)], :program => program, :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
        end
      end
    end

    assert_equal AbstractRequest::Status::NOT_ANSWERED, mentee.reload.sent_mentor_requests.first.status # mentor request not withdrawn

    # make the drafted group published
    assert_difference 'Group.active.size' do
      Group.last.publish(users(:f_admin))
    end
    assert_equal AbstractRequest::Status::WITHDRAWN, mentee.reload.sent_mentor_requests.first.status # mentor request withdrawn
  end

  def test_withdraw_mentor_request_on_reaching_mentee_limit_on_reactivating_closed_group
    program = programs(:albers)
    program.update_attributes!(:max_connections_for_mentee => 1)
    program.reload
    mentee = users(:student_4)
    assert_equal 2, mentee.sent_mentor_requests.size #has 2 unanswered mentor requests pending
    assert_equal 0, mentee.groups.active.size

    grp = mentee.groups.first
    # reactivate a closed connection
    expiry_time = (Time.now + 2.months).utc
    assert_emails 2 do
      assert_difference "RecentActivity.count" do
        grp.change_expiry_date(users(:f_admin), expiry_time, "Peace")
      end
    end

    assert_equal [AbstractRequest::Status::WITHDRAWN, AbstractRequest::Status::WITHDRAWN], mentee.reload.sent_mentor_requests.collect(&:status) # mentor request withdrawn
  end

  def test_withdraw_mentor_request_on_reaching_mentee_limit_on_adding_to_existing_group
    program = programs(:albers)
    program.update_attributes!(:max_connections_for_mentee => 1)
    program.reload
    group = groups(:mygroup)
    mentee = users(:student_4)
    assert_equal 2, mentee.sent_mentor_requests.size #has 2 unanswered mentor requests pending
    assert_equal 0, mentee.groups.active.size

    group.update_members(group.mentors, group.students + [mentee])
    assert_equal [AbstractRequest::Status::WITHDRAWN, AbstractRequest::Status::WITHDRAWN], mentee.reload.sent_mentor_requests.collect(&:status) # mentor request withdrawn
    assert_equal 1, mentee.groups.active.size
  end

  def test_create_mentoring_model_permissisons_and_items
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentor_role = program.get_roles(RoleConstants::MENTOR_NAME).first
    mentee_role = program.get_roles(RoleConstants::STUDENT_NAME).first
    Timecop.freeze(Time.new(2000)) do
      # create some task templates
      t1 = create_mentoring_model_task_template(duration: 2, required: true, role_id: mentee_role.id, title: "Sample1")
      t2 = create_mentoring_model_task_template(duration: 3, required: true, role_id: mentor_role.id, title: "Sample 2")
      t3 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t1.id, role_id: mentee_role.id, title: "Sample 3")
      MentoringModel::TaskTemplate.compute_due_dates([t1, t2, t3])
      program.reload
      # create group and create_mentoring_model_permissisons_and_items is called from observer
      group = nil
      Group.expects(:send_group_creation_notification_to_members).once
      assert_difference "ObjectRolePermission.count", 10 do
        assert_difference "MentoringModel::Task.count", 3 do
          group = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:f_mentor)], actor: users(:f_admin))
        end
      end

      mentoring_model_tasks = group.reload.mentoring_model_tasks
      attributes_to_check = ["required", "title", "description", "position", "action_item_type"]
      assert_equal [t1, t2, t3].map{|t| t.attributes.pick(*attributes_to_check)}, mentoring_model_tasks.map{|t| t.attributes.pick(*attributes_to_check)}
      assert_equal group.published_at + 2.days, mentoring_model_tasks[0].due_date
      assert_equal group.published_at + 3.days, mentoring_model_tasks[1].due_date
      assert_equal group.published_at + 4.days, mentoring_model_tasks[2].due_date
    end
  end

  def test_does_not_create_mentoring_model_objects_when_group_unpublished
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentor_role = program.get_roles(RoleConstants::MENTOR_NAME).first
    mentee_role = program.get_roles(RoleConstants::STUDENT_NAME).first
    program.reload

    group1 = nil
    group2 = nil
    t1 = create_mentoring_model_task_template(duration: 2, required: true, role_id: mentee_role.id, title: "Sample1")
    t2 = create_mentoring_model_task_template(duration: 3, required: true, role_id: mentor_role.id, title: "Sample 2")
    t3 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t1.id, role_id: mentee_role.id, title: "Sample 3")
    MentoringModel::TaskTemplate.compute_due_dates([t1, t2, t3])
    program.reload

    assert_no_difference "ObjectRolePermission.count" do
      assert_no_difference "MentoringModel::Task.count" do
        group1 = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:f_mentor)], actor: users(:f_admin), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
      end
    end

    #pending user
    assert_no_difference "ObjectRolePermission.count" do
      assert_no_difference "MentoringModel::Task.count" do
        group2 = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:pending_user)], actor: users(:f_admin), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
      end
    end

    assert users(:pending_user).state == User::Status::PENDING

    assert_difference "ObjectRolePermission.count", 10 do
      assert_difference "MentoringModel::Task.count", 3 do
        group1.publish(users(:f_admin))
      end
    end

    assert_difference "ObjectRolePermission.count", 10 do
      assert_difference "MentoringModel::Task.count", 3 do
        group2.publish(users(:f_admin))
      end
    end
    assert users(:pending_user).reload.state == User::Status::ACTIVE
  end

  def test_send_immediate_facilitation_messages_on_group_publish
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentor_role = program.get_roles(RoleConstants::MENTOR_NAME).first
    mentee_role = program.get_roles(RoleConstants::STUDENT_NAME).first
    program.reload

    group = nil
    facilitation_template_1 = create_mentoring_model_facilitation_template(send_on: 1)
    facilitation_template_2 = create_mentoring_model_facilitation_template(send_on: 0)
    program.reload
    assert_no_difference "FacilitationDeliveryLog.count" do
      group = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:f_mentor)], actor: users(:f_admin), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    end

    assert_difference "FacilitationDeliveryLog.count", 1 do
      group.publish(users(:f_admin))
    end

    0.upto(1) do |day|
      Timecop.travel(day.days.from_now)
      if day == 0 || day == 1
        if day == 0
          assert_difference "ActionMailer::Base.deliveries.size", 0 do
            program.deliver_facilitation_messages_v2
          end
        elsif day == 1
          assert_difference "ActionMailer::Base.deliveries.size", 1 do
            program.deliver_facilitation_messages_v2
          end
        end
      end
      Timecop.return
    end
  end

  def test_send_facilitation_messages_on_group_publish
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    mentor_role = program.get_roles(RoleConstants::MENTOR_NAME).first
    mentee_role = program.get_roles(RoleConstants::STUDENT_NAME).first
    program.reload

    group = nil
    facilitation_template_1 = create_mentoring_model_facilitation_template(send_on: 1)
    facilitation_template_2 = create_mentoring_model_facilitation_template(send_on: 0)
    program.reload
    assert_no_difference "FacilitationDeliveryLog.count" do
      group = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:f_mentor)], actor: users(:f_admin), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    end

    group.status = Group::Status::ACTIVE
    group.expiry_time = 1.week.from_now.to_date
    group.save!
    assert_difference "FacilitationDeliveryLog.count", 1 do
      GroupObserver.send_facilitation_messages_on_group_publish(group.id)
    end
  end

  def test_withdraw_mentor_requests_on_group_publish
    program = programs(:albers)
    group = nil
    student = users(:student_1)
    mentor = users(:f_mentor)
    member_ids = [student.id, mentor.id]

    assert_equal 1, MentorRequest.involving(member_ids).active.size
    assert_equal 0, MentorRequest.involving(member_ids).withdrawn.size

    assert_no_difference "MentorRequest.count" do
      group = create_group(program: programs(:albers), students: [student], mentors: [mentor], actor: users(:f_admin), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
    end

    assert_no_difference "MentorRequest.count" do
      group.publish(users(:f_admin))
    end

    assert_equal 0, MentorRequest.involving(member_ids).active.size
    assert_equal 1, MentorRequest.involving(member_ids).withdrawn.size
  end

  def test_does_not_create_mentoring_model_objects
    program = programs(:albers)
    mentor_role = program.get_roles(RoleConstants::MENTOR_NAME).first
    mentee_role = program.get_roles(RoleConstants::STUDENT_NAME).first
    admin_role = program.get_roles(RoleConstants::ADMIN_NAME).first
    users(:f_mentor).update_attributes!(max_connections_limit: 5)
    program.reload
    mentoring_model = program.default_mentoring_model

    t1 = create_mentoring_model_task_template(duration: 2, required: true, role_id: mentee_role.id, title: "Sample1")
    t2 = create_mentoring_model_task_template(duration: 3, required: true, role_id: mentor_role.id, title: "Sample 2")
    t3 = create_mentoring_model_task_template(duration: 2, required: true, associated_id: t1.id, role_id: mentee_role.id, title: "Sample 3")
    MentoringModel::TaskTemplate.compute_due_dates([t1, t2, t3])
    program.reload

    assert_no_difference "ObjectRolePermission.count" do
      assert_no_difference "MentoringModel::Task.count" do
        group = create_group(program: programs(:albers), students: [users(:f_student)], mentors: [users(:f_mentor)], actor: users(:f_admin))
      end
    end

    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)

    assert_difference "ObjectRolePermission.count", 10 do
      assert_difference "MentoringModel::Task.count", 3 do
        group = create_group(program: programs(:albers), students: [users(:student_5)], mentors: [users(:f_mentor)], actor: users(:f_admin))
      end
    end

    program.reload
    assert mentoring_model.can_manage_mm_tasks?(admin_role)
    mentoring_model.deny_manage_mm_tasks!(admin_role)
    assert_false mentoring_model.reload.can_manage_mm_tasks?(admin_role)

    assert_difference "ObjectRolePermission.count", 9 do
      assert_no_difference "MentoringModel::Task.count" do
        group = create_group(program: programs(:albers), students: [users(:student_6)], mentors: [users(:f_mentor)], actor: users(:f_admin))
      end
    end
  end

  def test_assign_templates_based_on_group
    program = programs(:albers)
    drafted_group = program.groups.drafted.first
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    new_mentoring_model = create_mentoring_model(mentoring_period: 2.months)
    drafted_group.mentoring_model = new_mentoring_model
    drafted_group.save!
    roles_hash = program.roles.for_mentoring_models.group_by(&:name)
    new_mentoring_model.allow_manage_mm_milestones!([roles_hash[RoleConstants::ADMIN_NAME].first])
    new_mentoring_model.allow_manage_mm_tasks!([roles_hash[RoleConstants::ADMIN_NAME].first, roles_hash[RoleConstants::STUDENT_NAME].first])

    milestone_template = create_mentoring_model_milestone_template
    new_t1 = create_mentoring_model_task_template(title: "House Of Cards", mentoring_model_id: new_mentoring_model.id, milestone_template_id: milestone_template.id)
    new_t2 = create_mentoring_model_task_template(title: "Claire Underwood", mentoring_model_id: new_mentoring_model.id, milestone_template_id: milestone_template.id)
    new_t3 = create_mentoring_model_task_template(title: "Frank Underwood", mentoring_model_id: new_mentoring_model.id, milestone_template_id: milestone_template.id)

    assert_difference "ObjectRolePermission.count", 3  do
      assert_difference "MentoringModel::Task.count", 3 do
        drafted_group.update_attributes!(notes: "Frank Underwood")
        drafted_group.publish(users(:f_admin))
      end
    end

    assert_not_equal program.default_mentoring_model.id, drafted_group.mentoring_model_id
    assert_equal new_mentoring_model.id, drafted_group.mentoring_model_id
    assert_equal_unordered ["manage_mm_milestones", "manage_mm_tasks", "manage_mm_tasks"], drafted_group.object_permissions.pluck(:name)
    assert_equal ["House Of Cards", "Claire Underwood", "Frank Underwood"], drafted_group.mentoring_model_tasks.collect(&:title)
  end

  def test_assign_templates_after_create
    program = programs(:albers)
    program.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    group = nil

    assert_no_difference "ObjectRolePermission.count" do
      assert_difference "Group.count" do
        group = create_group(:students => [users(:f_student)], :mentors => [users(:f_mentor)], :program => programs(:albers), :status => Group::Status::DRAFTED, :creator_id => users(:f_admin).id)
      end
    end

    time_traveller(Time.local(2013, 1, 16, 10, 5, 0)) do
      mentoring_model = group.program.default_mentoring_model
      mentoring_model.mentoring_period = 1.month
      mentoring_model.save!

      assert_equal mentoring_model, group.mentoring_model
      assert_emails 2 do
        assert_difference "ObjectRolePermission.count", 10 do
          group.publish(users(:f_admin))
        end
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_match "Please review your profile and verify all the information there is still correct. Update your profile information if anything is wrong or no longer valid. This will help your student learn more about you and your common interests", get_html_part_from(email)
    assert_match "Connect with your student today in the mentoring connection area.", get_html_part_from(email)
    assert_match "Start by reviewing initial tasks for both you and your student.", get_html_part_from(email)
    assert_match "as your student", get_html_part_from(email)
    assert_match "Visit your mentoring connection area", get_html_part_from(email)
    assert_match "/p/albers/contact_admin\"", get_html_part_from(email)
  end

  def test_send_pending_state_emails
    program = programs(:albers)
    enable_project_based_engagements!
    group = program.groups.drafted.first
    group.members.each do |user|
      user.program_notification_setting = UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE
      user.save!
    end
    ProjectRequest.expects(:close_pending_requests_if_required).with(group.get_user_id_role_id_hash)
    ProjectRequest.expects(:close_pending_requests_if_required).with({users(:f_student).id => programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME).id}).twice
    ProjectRequest.expects(:close_pending_requests_if_required).with({users(:pending_user).id => programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME).id})

    assert_emails group.members.size do
      group.update_attributes!(status: Group::Status::PENDING)
    end

    email = ActionMailer::Base.deliveries.last
    to_email_address = email.header.fields.find{|field| field.name == "To"}.value
    user_ids = Member.find_by(email: to_email_address).users.pluck(:id)
    user = group.members.where(id: user_ids).first
    assert_equal "You have been added as a #{group.has_mentor?(user) ? "mentor" : "student"} to #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}\/profile/, mail_content
    assert_match /We will notify you when the mentoring connection starts. Meanwhile, you can visit the mentoring connection to see your other available activities./, mail_content

    assert_no_emails do
      group = create_group(name: "Claire Underwood", students: [users(:f_student)], mentors: [], program: program, status: Group::Status::PENDING)
    end

    group1 = create_group(name: "Claire Underwood", students: [users(:f_student)], mentors: [users(:pending_user)], program: program, status: Group::Status::PENDING)
    assert users(:pending_user).reload.state == User::Status::ACTIVE
  end

def test_add_remove_emails_in_pending_state
    enable_project_based_engagements!
    group = nil
    program = programs(:albers)

    assert_no_emails do
      group = create_group(name: "Claire Underwood", students: [], mentors: [], program: program, status: Group::Status::PENDING)
    end

    group.skip_observer = nil

    assert_emails 2 do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          group.update_members([users(:f_mentor)], [users(:f_student)])
        end
      end
    end

    group_addition_ra = RecentActivity.last
    assert_equal group, group_addition_ra.ref_obj
    assert_equal RecentActivityConstants::Type::GROUP_MEMBER_ADDITION_REMOVAL, group_addition_ra.action_type
    assert_equal RecentActivityConstants::Target::NONE, group_addition_ra.target
    assert_nil group_addition_ra.message
    assert_nil group_addition_ra.member
    assert_equal 1, group_addition_ra.connection_activities.count
    connection_activity = group_addition_ra.connection_activities.first
    assert_equal group, connection_activity.group

    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered [users(:f_mentor), users(:f_student)].collect(&:email), emails.collect(&:to).flatten
    email = emails.last
    mail_content = get_html_part_from(email)
    assert_match "p/albers/groups/#{group.id}/profile", mail_content
    assert_match /We will notify you when the mentoring connection starts. Meanwhile, you can visit the mentoring connection to see your other available activities./, mail_content

    assert_emails 1 do
      group.update_members([], [users(:f_student)], users(:f_admin))
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal users(:f_mentor).email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match "p/albers/groups/find_new", mail_content
    assert_match /Program Administrator has removed you from #{group.name}/, email.subject
    assert_match /However, there are other .*mentoring connections.* that you may find more suitable!/, mail_content
    assert_match "/p/albers/contact_admin", mail_content
    assert_match "Visit other mentoring connection", mail_content
  end

  def test_publish_project_with_pbe
    enable_project_based_engagements!
    group = nil
    program = programs(:albers)
    group = create_group(name: "Claire Underwood", students: [users(:f_student)], mentors: [users(:f_mentor)], program: program, status: Group::Status::PENDING)

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PUBLISHED, group)
    assert_emails 2 do
      group.publish(users(:f_admin))
    end

    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered [users(:f_mentor), users(:f_student)].collect(&:email), emails.collect(&:to).flatten
    email = emails.last
    assert_equal "Your mentoring connection '#{group.name}' has started", email.subject
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}/, mail_content
    assert_match /You can start participating by reviewing the mentoring connection plan and reaching out to other participants./, mail_content
    assert_match "Visit the mentoring connection", mail_content

    group = groups(:drafted_group_1)
    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_PUBLISHED, group)
    assert_emails group.members.size do
      group.publish(users(:f_admin))
    end

    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered group.members.collect(&:email), emails.collect(&:to).flatten
    email = emails.last
    assert_equal "Your mentoring connection '#{group.name}' has started", email.subject
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}/, mail_content
    assert_match /You can start participating by reviewing the mentoring connection plan and reaching out to other participants./, mail_content
  end

  def test_mails_for_publish_scenario
    program = programs(:albers)
    teacher_role = create_role(name: "teacher", program: program, for_mentoring: true)
    user = users(:student_7)
    user.roles += [teacher_role]
    user.save!
    group = create_group(name: "Claire Underwood", students: [users(:f_student)], mentors: [users(:f_mentor)], program: program, status: Group::Status::DRAFTED, :creator_id => users(:f_admin).id)

    Push::Base.expects(:queued_notify).never #program is not PBE
    assert_no_emails do
      group.update_members(group.mentors, group.students, nil, other_roles_hash: {teacher_role => [user]})
    end

    group.reload.old_members_by_role = nil
    assert_equal [user], group.reload.custom_users
    Push::Base.expects(:queued_notify).never #program is not PBE
    assert_emails 3 do
      group.publish(users(:f_admin))
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "You have been added to a mentoring connection, Claire Underwood!", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/albers\/groups\/#{group.id}/, mail_content
    assert_match "You have been assigned to Claire Underwood.", mail_content
    assert_match "Please review your profile and that verify all the information there is still correct. Update your profile information if anything is wrong or no longer valid. This will help your mentoring partners learn more about you and your common interests.", mail_content
    assert_match "Connect with them today in the mentoring connection area.", mail_content
    assert_match "/p/albers/groups/#{group.id}?src=mail", mail_content
    assert_match "Visit your mentoring connection area", mail_content
    assert_match "/p/albers/contact_admin\"", mail_content
  end

  def test_user_marked_for_indexing
    # We are also testing ES reindexing. Please do not remove the test case.
    g = groups(:mygroup)
    closed_group = Group.closed.first
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Group, any_parameters).at_least(0)
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(User, [9, 3])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(User, [9])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(User, [3])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [9, 3])

    g.terminate!(users(:f_admin), "test", g.program.permitted_closure_reasons.first.id)

    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(User, [14])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(User, [43])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).times(2).with(User, [14, 43])
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).with(Member, [14, 43])
    closed_group.actor = users(:f_admin)
    closed_group.update_attribute(:status, Group::Status::ACTIVE)  # 1st time

    closed_group.update_attribute(:closed_at, DateTime.now) # 2nd time
  end

  def test_coach_rating_mails_on_group_termination
    g = groups(:mygroup)
    program = programs(:albers)

    assert_false program.coach_rating_enabled?
    assert_emails 2 do
      g.terminate!(users(:f_admin), "Test reason", program.permitted_closure_reasons.first.id)
    end
    assert_emails 2 do
      g.change_expiry_date(users(:f_admin), Time.now + 2.months, "Peace")
    end

    program.enable_feature(FeatureName::COACH_RATING, true)
    assert_emails 3 do
      g.reload.terminate!(users(:f_admin), "Test reason", program.permitted_closure_reasons.first.id)
    end
  end

  def test_after_save
    Group.any_instance.expects(:create_group_forum).twice
    DelayedEsDocument.expects(:delayed_bulk_update_es_documents).once.with(ProjectRequest, [23, 28])
    group = groups(:group_pbe_1)
    group.update_attributes!(name: "Test Name")
    # should not reindex on updating status
    group.update_attributes!(notes: "Test Notes")
  end

  def test_active_to_close_project
    group = groups(:group_pbe)
    program = group.program
    ProjectRequest.expects(:mark_rejected).once
    group.terminate!(users(:f_admin_pbe), "Test reason", program.permitted_closure_reasons.first.id)
  end
end
