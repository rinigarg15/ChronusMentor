require_relative './../test_helper.rb'

class ProjectRequestTest < ActiveSupport::TestCase

  def test_requires_message
    assert_no_difference 'ProjectRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :message do
        ProjectRequest.create!(program: programs(:pbe), sender: users(:f_student_pbe), group: groups(:group_pbe_1))
      end
    end
  end

  def test_requires_program
    assert_no_difference 'ProjectRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :program do
        ProjectRequest.create!(message: "Hi", sender: users(:f_student_pbe), group: groups(:group_pbe_1))
      end
    end
  end

  def test_requires_sender
    assert_no_difference 'ProjectRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender do
        ProjectRequest.create!(message: "Hi", program: programs(:pbe), group: groups(:group_pbe_1))
      end
    end
  end

  def test_requires_group
    assert_no_difference 'ProjectRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :group do
        ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender: users(:f_student_pbe))
      end
    end
  end

  def test_requires_status_and_inclusion
    req = ProjectRequest.new(message: "Hi", program: programs(:pbe), group: groups(:group_pbe_1), sender: users(:f_student_pbe), status: nil)
    assert_false req.valid?
    assert req.errors[:status]

    req_1 = ProjectRequest.new(message: "Hi", program: programs(:pbe), group: groups(:group_pbe_1), sender: users(:f_student_pbe), status: 5)
    assert_false req_1.valid?
    assert req_1.errors[:status]
  end

  def test_associations
    project_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
    assert_equal groups(:group_pbe_1), project_request.group
    assert_equal users(:f_student_pbe), project_request.sender
  end

  def test_valid_creation
    assert_difference 'ProjectRequest.count' do
      @project_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
    end

    assert_equal programs(:pbe), @project_request.program
    assert_equal users(:f_student_pbe), @project_request.sender
    assert_equal groups(:group_pbe_1), @project_request.group
    assert @project_request.active?
  end

  def test_sender_and_group_must_belong_to_program
    program = programs(:pbe)
    sender = users(:f_student)
    member_sender = users(:f_student_pbe)
    group = groups(:mygroup)
    member_group = groups(:group_pbe_1)

    # Check associations.
    assert_false sender.member_of?(program)
    assert_not_equal group.program, program
    assert member_sender.member_of?(program)
    assert_equal member_group.program, program

    assert_no_difference 'ProjectRequest.count' do
      # Sender and Group both are not part of program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :group, "is not part of the program" do
        ProjectRequest.create!(message: "Hi", program: program, sender_id: sender.id, group_id: group.id)
      end
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender, "is not member of the program" do
        ProjectRequest.create!(message: "Hi", program: program, sender_id: sender.id, group_id: group.id)
      end

      # Only Sender is not part of program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender, "is not member of the program" do
        ProjectRequest.create!(message: "Hi", program: program, sender_id: sender.id, group_id: member_group.id)
      end

      # Only Group is not part of program
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :group, "is not part of the program" do
        ProjectRequest.create!(message: "Hi", program: program, sender_id: member_sender.id, group_id: group.id)
      end
    end
  end

  def test_max_one_pending_request_from_sender_to_group_in_program
    # Create a request
    assert_difference 'ProjectRequest.count' do
      @first_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
    end

    # Create another request for the same combination
    assert_no_difference 'ProjectRequest.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sender,
        "has already sent a request to this project" do
        ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
      end
    end

    @first_request.status = AbstractRequest::Status::REJECTED
    @first_request.response_text = "Sorry rejected"
    @first_request.save!

    # The request can now been saved.
    assert_nothing_raised do
      assert_difference 'ProjectRequest.count', 1 do
        @second_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id)
      end
    end
  end

  def test_sender_role_id_belongs_to_role
    user = users(:f_student_pbe)
    user_role_id = user.roles.find_by(name: "student").id
    assert_nothing_raised do
      assert_difference 'ProjectRequest.count', 1 do
        @second_request = ProjectRequest.create!(message: "Hi", program: programs(:pbe), sender_id: users(:f_student_pbe).id, group_id: groups(:group_pbe_1).id, sender_role_id: user_role_id)
      end
    end
    assert_equal user_role_id, @second_request.role.id
  end

  def test_response_not_mandatory_for_rejection
    req = ProjectRequest.new(:message => "Hi", :sender_id => users(:f_student_pbe).id, :group_id => groups(:group_pbe_1).id, :program => programs(:pbe))
    assert req.valid?
    req.status = AbstractRequest::Status::REJECTED
    assert req.valid?
  end

  def test_send_emails_to_admins_and_owners
    program = programs(:pbe)
    project_request = program.project_requests.first
    group = project_request.group
    user = users(:f_admin_pbe)
    sender_name = project_request.sender.name

    assert_emails 1 do
      ProjectRequest.send_emails_to_admins_and_owners(project_request.id, JobLog.generate_uuid)
    end

    email = ActionMailer::Base.deliveries.last

    assert_equal "#{sender_name} requests to join the mentoring connection, #{group.name}", email.subject
    assert_equal user.email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/pbe\/groups\/#{group.id}\/profile/, mail_content
    assert_match /p\/pbe\/project_requests/, mail_content
    assert_match "View Request", mail_content

    new_f_mentor = users(:f_mentor_pbe)
    new_f_mentor.add_role(RoleConstants::ADMIN_NAME)

    assert_emails 2 do
      ProjectRequest.send_emails_to_admins_and_owners(project_request.id, JobLog.generate_uuid)
    end

    emails = ActionMailer::Base.deliveries.last(2)
    email = emails.last

    assert_equal "#{sender_name} requests to join the mentoring connection, #{group.name}", email.subject
    assert_equal_unordered [user, new_f_mentor].collect(&:email), emails.collect(&:to).flatten
    mail_content = get_html_part_from(email)
    assert_match /p\/pbe\/groups\/#{group.id}\/profile/, mail_content
    assert_match /p\/pbe\/project_requests/, mail_content
    assert_match "If the mentoring connection is a good fit, please accept their request as soon as possible.", mail_content
    assert_match "If you must decline, please do so in a timely manner and be tactful.", mail_content
  end

  def test_mark_accepted
    program = programs(:pbe)
    admin = users(:f_admin_pbe)
    project_request = program.project_requests.active.first
    group = project_request.group
    group.students -= [project_request.sender]
    group.save!

    teacher_role = create_role(name: "teacher", for_mentoring: true)
    user = program.all_users.where("id NOT IN (?)", group.members.collect(&:id)).first
    user.roles += [teacher_role]
    user.save!
    user.reload

    group.update_members(group.mentors, group.students, nil, other_roles_hash: {teacher_role => [user]})
    group.reload
    original_mentors = group.mentors.all
    original_students = group.students.all
    assert_equal [user], group.custom_users.all

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT, project_request).never
    Group.any_instance.stubs(:update_members).returns(false).once
    assert_no_difference "Connection::Membership.count" do
      project_request.mark_accepted(admin)
    end
    group.reload
    project_request.reload
    assert_false project_request.accepted?
    assert_nil project_request.receiver
    assert_equal_unordered original_mentors, group.mentors
    assert_equal_unordered original_students, group.students
    assert_equal [user], group.custom_users

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT, project_request).once
    Group.any_instance.unstub(:update_members)
    assert_emails 1 do
      assert_difference "Connection::Membership.count", 1 do
        project_request.mark_accepted(admin)
      end
    end
    group.reload
    project_request.reload
    assert project_request.accepted?
    assert_equal admin, project_request.receiver
    assert_equal_unordered original_mentors, group.mentors
    assert_equal_unordered (original_students + [project_request.sender]), group.students
    assert_equal [user], group.custom_users

    assert_no_emails do
      assert_nothing_raised do
        project_request.reload.mark_accepted(users(:f_admin_pbe))
      end
    end
    assert project_request.reload.accepted?
  end

  def test_mark_accepted_active_group
    group = groups(:group_pbe)
    project_request = create_project_request(group, users(:pbe_student_1))
    admin = users(:f_admin_pbe)

    Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_CONNECTION_REQUEST_ACCEPT, project_request).once
    ProjectRequest.expects(:send_request_change_mail).once
    assert_difference "Connection::Membership.count", 1 do
      project_request.mark_accepted(admin)
    end
  end

  def test_mark_rejected
    program = programs(:pbe)
    project_request = program.project_requests.active.first
    group = project_request.group

    assert_emails 1 do
      ProjectRequest.mark_rejected([project_request.id], users(:f_admin_pbe), "Mentor is not interested", AbstractRequest:: Status::REJECTED)
    end
    project_request.reload
    assert_equal project_request.response_text, "Mentor is not interested"
    assert_equal project_request.status, AbstractRequest::Status::REJECTED
    assert_equal project_request.receiver, users(:f_admin_pbe)

    assert_no_emails do
      ProjectRequest.mark_rejected([project_request.id], users(:f_admin_pbe), "Mentor is not interested", AbstractRequest:: Status::REJECTED)
    end
    assert project_request.reload.rejected?
  end

  def test_scope_with_role
    program = programs(:pbe)
    student_role = program.find_role(RoleConstants::STUDENT_NAME)
    mentor_role = program.find_role(RoleConstants::MENTOR_NAME)
    pending_project_requests = program.project_requests.active
    user = users(:pbe_student_4)

    assert_equal_unordered pending_project_requests.pluck(:id), program.project_requests.with_role(student_role).active.pluck(:id)
    assert_equal_unordered user.sent_project_requests.pluck(:id), user.sent_project_requests.with_role(student_role).pluck(:id)
    assert_empty user.sent_project_requests.with_role(mentor_role)
  end

  def test_notify_expired_project_requests
    program = programs(:pbe)
    program.update_attribute :circle_request_auto_expiration_days, 11 

    assert_equal ProjectRequest.closable('circle_request_auto_expiration_days').size, 0
    assert_no_emails do
      ProjectRequest.notify_expired_project_requests
    end

    requests = program.project_requests.first(2)
    ProjectRequest.where(id: requests.collect(&:id)).update_all(created_at: 15.days.ago)

    ProjectRequest.stubs(:closable).with('circle_request_auto_expiration_days').returns(ProjectRequest.where(id: requests.collect(&:id)))
    
    assert_emails(2) do
      ProjectRequest.notify_expired_project_requests
    end
  end

  def test_close_request
    program = programs(:pbe)
    program.update_attribute(:circle_request_auto_expiration_days, 11)
    pr = program.project_requests.last

    pr.stubs(:close!).with("Auto closed because it has not been responded.").at_least(1)
    pr.close_request!
  end

  def test_send_project_request_reminders
    #no notification to non pbe programs
    ProjectRequest.update_all(status: AbstractRequest::Status::ACCEPTED)
    program = programs(:albers)
    group = create_group(name: "Claire Underwood", mentors: [users(:f_mentor)], students: [users(:f_student)], program: programs(:albers), status: Group::Status::PENDING)
    request = create_project_request(group, users(:student_3))
    group.membership_of(users(:f_mentor)).update_attributes!(owner: true)
    assert users(:f_mentor).is_owner_of?(group)
    program.update_attributes(needs_project_request_reminder: true)
    program.update_attributes(project_request_reminder_duration: 1)
    current_time = Time.now.utc
    request.update_attributes(created_at: (current_time.beginning_of_day + 3.hours - 1.day))
    start_time = (current_time - program.project_request_reminder_duration.days).beginning_of_day
    end_time = start_time.end_of_day
    assert_equal [request], program.project_requests.active.where(:created_at => start_time..end_time)
    assert_false program.project_based?
    assert program.needs_project_request_reminder
    assert_emails 0 do
      ProjectRequest.send_project_request_reminders
    end

    #notification to pbe programs
    program.update_attributes!(engagement_type: Program::EngagementType::PROJECT_BASED)
    assert program.project_based?
    assert_emails 1  do
      ProjectRequest.send_project_request_reminders
    end
    assert_equal current_time.to_date, request.reload.reminder_sent_time.to_date
    email = ActionMailer::Base.deliveries.last
    assert_equal [users(:f_mentor).email], email.to
    mail_content = get_html_part_from(email)
    assert_match "#{request.sender.name(name_only: true)} asked to join ", mail_content
      
    #no notification if needs_project_request_reminder is false
    request.update_attributes(reminder_sent_time: nil)
    program.update_attributes(needs_project_request_reminder: false)
    assert_equal [request], program.project_requests.active.where(:created_at => start_time..end_time)
    assert_false program.needs_project_request_reminder
    assert program.project_based?
    assert_emails 0 do
      ProjectRequest.send_project_request_reminders
    end
    
    #no notification for old reqs
    request.update_attributes(reminder_sent_time: nil)
    program.update_attributes(needs_project_request_reminder: true)
    assert program.needs_project_request_reminder
    request.update_attributes(created_at: (current_time.beginning_of_day + 3.hours - 2.day))
    assert_equal [], program.project_requests.active.where(:created_at => start_time..end_time)
    assert program.project_based?
    assert_emails 0 do
      ProjectRequest.send_project_request_reminders
    end

    #notification for requests with-out any group owner
    request.update_attributes(created_at: (current_time.beginning_of_day + 3.hours - 1.day))
    assert_equal [request], program.project_requests.active.where(:created_at => start_time..end_time)
    group.membership_of(users(:f_mentor)).update_attributes!(owner: false)
    assert_false users(:f_mentor).is_owner_of?(group)
    assert_emails 0 do
      ProjectRequest.send_project_request_reminders
    end
  end

  def test_send_project_request_reminders_multiple_reqs
    #notification for requests with multiple group owner
    program = programs(:pbe)
    student_user = users(:pbe_student_2)
    mentor_user = users(:pbe_mentor_2)
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    groups(:group_pbe_2).membership_of(mentor_user).update_attributes!(owner: true)
    current_time = Time.now.utc
    ProjectRequest.update_all(created_at: (current_time.beginning_of_day + 3.hours - 1.day))
    start_time = (current_time - program.project_request_reminder_duration.days).beginning_of_day
    end_time = start_time.end_of_day
    program.update_attributes(needs_project_request_reminder: true)
    program.update_attributes(project_request_reminder_duration: 1)
    assert_emails 2 do
      ProjectRequest.send_project_request_reminders
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal_unordered [student_user.email, mentor_user.email].flatten, emails.collect(&:to).flatten

    program = programs(:albers)
    group = create_group(name: "Claire Underwood", mentors: [users(:f_mentor)], students: [users(:f_student)], program: programs(:albers), status: Group::Status::PENDING)
    request = create_project_request(group, users(:student_3))
    group.membership_of(users(:f_mentor)).update_attributes!(owner: true)
    assert users(:f_mentor).is_owner_of?(group)
    program.update_attributes(needs_project_request_reminder: true)
    program.update_attributes(project_request_reminder_duration: 1)
    current_time = Time.now.utc
    request.update_attributes(created_at: (current_time.beginning_of_day + 3.hours - 1.day))
    start_time = (current_time - program.project_request_reminder_duration.days).beginning_of_day
    end_time = start_time.end_of_day
    assert_equal [request], program.project_requests.active.where(:created_at => start_time..end_time)
    program.update_attributes!(engagement_type: Program::EngagementType::PROJECT_BASED)

    ProjectRequest.update_all(created_at: (current_time.beginning_of_day + 3.hours - 1.day))
    ProjectRequest.update_all(reminder_sent_time: nil)

    assert_emails 3 do
      ProjectRequest.send_project_request_reminders
    end
    emails = ActionMailer::Base.deliveries.last(3)
    assert_equal_unordered [student_user.email, mentor_user.email, users(:f_mentor).email].flatten, emails.collect(&:to).flatten

    #notification for multiple current requests for one user

    request1 = create_project_request(groups(:group_pbe_2), users(:pbe_student_1))
    ProjectRequest.update_all(created_at: (current_time.beginning_of_day + 3.hours - 1.day))
    ProjectRequest.update_all(reminder_sent_time: nil)
    groups(:group_pbe_2).membership_of(mentor_user).update_attributes!(owner: false)
    program.update_attributes(needs_project_request_reminder: false)

    assert_emails 2 do
      ProjectRequest.send_project_request_reminders
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert_equal [[student_user.email]], emails.collect(&:to).uniq
    mail_content = get_html_part_from(emails.last)
    assert_match "#{request1.sender.name(name_only: true)} asked to join ", mail_content
  end

  def test_withdraw
    project_request = ProjectRequest.where.not(status: ProjectRequest::Status::WITHDRAWN).first
    response_text = "Withdrawing request"
    project_request.withdraw!(response_text)
    assert_equal ProjectRequest::Status::WITHDRAWN, project_request.reload.status
    assert_equal response_text, project_request.response_text
  end

  def test_with_role
    request = ProjectRequest.first
    role_id = request.sender_role_id
    assert request.with_role?(Role.find(role_id))
    assert_false request.with_role?(Role.where.not(id: role_id).first)
  end

  def test_close_pending_requests_if_required
    student_role = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME)
    mentor_role = programs(:pbe).roles.find_by(name: RoleConstants::MENTOR_NAME)
    user_id_role_id_hash = { users(:pbe_student_2).id => student_role.id, users(:f_mentor_pbe).id => mentor_role.id }
    student_role_project_requests = ProjectRequest.where(sender_role_id: student_role.id)
    User.any_instance.expects(:allow_project_requests_for_role?).returns(false).twice
    User.any_instance.stubs(:get_active_sent_project_requests_for_role).returns(student_role_project_requests)
    student_role_project_requests.each{ |project_request| project_request.expects(:close_request!).with("Reached the mentoring connection join limit.").twice }
    ProjectRequest.close_pending_requests_if_required(user_id_role_id_hash)
  end

  def test_get_project_request_path_for_privileged_users
    program = programs(:pbe)
    organization = program.organization
    params = { filters: { filter_1: "filter_1" }, root: program.root, host: organization.domain, subdomain: organization.subdomain }
    assert_equal Rails.application.routes.url_helpers.project_requests_url(params), ProjectRequest.get_project_request_path_for_privileged_users(users(:f_mentor_pbe), params)
    assert_equal Rails.application.routes.url_helpers.manage_project_requests_url(params), ProjectRequest.get_project_request_path_for_privileged_users(users(:f_admin_pbe), params)
  end
end