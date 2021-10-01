require_relative './../../test_helper.rb'

class UserObserverTest < ActiveSupport::TestCase
  def setup
    super
    # Required for testing mails
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_recent_activity_for_user_role_change
    RecentActivity.destroy_all
    student = users(:f_student)

    # Recent Activity created for promotion to admin, mentor
    assert_difference('RecentActivity.count') do
      student.promote_to_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    end
    assert_difference('RecentActivity.count') do
      student.promote_to_role!(RoleConstants::MENTOR_NAME, users(:f_admin))
    end

    # No recent activity for demotion
    assert_difference('RecentActivity.count' ,1) do
      student.demote_from_role!(RoleConstants::ADMIN_NAME, users(:f_admin))
    end
    assert_difference('RecentActivity.count', 1) do
      student.demote_from_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    end

    # Recent activity for promotion to student with target none
    assert_difference('RecentActivity.count') do
      student.promote_to_role!(RoleConstants::STUDENT_NAME, users(:f_admin))
    end
    assert_equal RecentActivityConstants::Target::ADMINS, RecentActivity.last.target

    assert_difference('RecentActivity.count', -5) do
      student.destroy
    end
  end

  def test_user_state_change_not_created
    user = nil
    assert_difference("UserStateChange.count", 1) do
      user = create_user(state: User::Status::PENDING)
    end

    user.created_for_sales_demo = true
    assert_no_difference("UserStateChange.count") do
      assert_no_difference "ConnectionMembershipStateChange.count" do
        user.roles = user.program.roles
      end
    end

    user.created_for_sales_demo = true
    assert_no_difference("UserStateChange.count") do
      assert_no_difference "ConnectionMembershipStateChange.count" do
        user.roles = [user.program.roles.first]
      end
    end

    user.created_by = users(:f_admin)
    user.state = User::Status::ACTIVE
    user.created_for_sales_demo = true
    assert_no_difference("UserStateChange.count") do
      assert_no_difference "ConnectionMembershipStateChange.count" do
        user.save!
      end
    end

  end

  def test_track_user_state_changes
    Timecop.freeze do
      user = nil
      date_id = Time.now.utc.to_i / 1.day.to_i
      assert_difference("UserStateChange.count", 1) do
        user = create_user(state: User::Status::PENDING)
      end
      student_role = user.roles[0].program.roles.find_by(name: RoleConstants::STUDENT_NAME)
      mentor_role = user.roles[0].program.roles.find_by(name: RoleConstants::MENTOR_NAME)
      admin_role = user.roles[0].program.roles.find_by(name: RoleConstants::ADMIN_NAME)
      assert_equal date_id, user.reload.state_transitions.last.date_id
      assert_equal_hash({"state" => {"from"=>nil, "to"=>User::Status::PENDING}, "role" => {"from"=>nil, "to"=>[student_role.id]}}, user.reload.state_transitions.last.info_hash)

      assert_difference("UserStateChange.count", 3) do
        assert_difference "ConnectionMembershipStateChange.count", 3 do
          g1 = create_group(:mentors => [users(:mentor_4)], :students => [user])
        end
      end
      
      assert_equal User::Status::PENDING, ConnectionMembershipStateChange.last(3).first.info_hash[:user][:from_state]
      assert_equal User::Status::ACTIVE, ConnectionMembershipStateChange.last(3).first.info_hash[:user][:to_state]

      assert_false user.is_mentor?
      assert user.is_student?
      assert_equal 3, user.reload.state_transitions.size
      assert_equal_hash({"role"=>{"from_role"=>[], "to_role"=>[student_role.id]}}, user.reload.state_transitions.last.connection_membership_info_hash)
      user.role_names = user.role_names + [mentor_role.name, admin_role.name]
      assert_equal 5, user.reload.state_transitions.size
      assert_equal date_id, user.reload.state_transitions.last.date_id
      assert_equal_hash({"state" => {"from"=>User::Status::ACTIVE, "to"=>User::Status::ACTIVE}, "role" => {"from"=>[student_role.id], "to"=>[student_role.id, mentor_role.id]}}, user.reload.state_transitions[-2].info_hash)
      assert_equal_hash({"state" => {"from"=>User::Status::ACTIVE, "to"=>User::Status::ACTIVE}, "role" => {"from"=>[student_role.id, mentor_role.id], "to"=>[student_role.id, mentor_role.id, admin_role.id]}}, user.reload.state_transitions[-1].info_hash)
      user.role_names = [mentor_role.name]
      assert_equal 7, user.reload.state_transitions.size
      assert_equal date_id, user.reload.state_transitions.last.date_id
      assert_equal_hash({"state" => {"from"=>User::Status::ACTIVE, "to"=>User::Status::ACTIVE}, "role" => {"from"=>[student_role.id, mentor_role.id, admin_role.id], "to"=>[mentor_role.id, admin_role.id]}}, user.reload.state_transitions[-2].info_hash)
      assert_equal_hash({"state" => {"from"=>User::Status::ACTIVE, "to"=>User::Status::ACTIVE}, "role" => {"from"=>[mentor_role.id, admin_role.id], "to"=>[mentor_role.id]}}, user.reload.state_transitions.last.info_hash)
      
      assert_equal User::Status::ACTIVE, ConnectionMembershipStateChange.last.info_hash[:user][:from_state]
      assert_equal User::Status::ACTIVE, ConnectionMembershipStateChange.last.info_hash[:user][:to_state]

      user.state_changer_id = users(:f_admin).id
      user.state_change_reason = "test suspension"
      assert_difference("UserStateChange.count") do
        suspend_user(user)
      end
      assert_equal 8, user.reload.state_transitions.size
      assert_equal date_id, user.reload.state_transitions.last.date_id
      assert_equal_hash({"state" => {"from"=>User::Status::ACTIVE, "to"=>User::Status::SUSPENDED}, "role" => {"from"=>[mentor_role.id], "to"=>[mentor_role.id]}}, user.reload.state_transitions.last.info_hash)
    end
  end

  def test_admin_creation_creates_recent_activity
    program = programs(:albers)
    assert_difference('User.count') do
      assert_difference('RecentActivity.count') do
        create_user(:role_names => [RoleConstants::ADMIN_NAME], :program => program)
      end
    end
    ra = RecentActivity.last
    user = User.last
    assert_equal [RoleConstants::ADMIN_NAME], user.role_names
    assert_equal user, ra.get_user(program)
    assert_equal [program], ra.programs
    assert_equal RecentActivityConstants::Type::ADMIN_CREATION, ra.action_type
    assert_equal RecentActivityConstants::Target::ADMINS, ra.target
    assert_equal user, ra.ref_obj
  end

  def test_user_activation
    RecentActivity.destroy_all
    student = users(:f_student)
    student.state_changer = users(:f_admin)
    student.state_change_reason = "Sorry for Deletion"
    suspend_user(student)

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference('RecentActivity.count') do
        student.reactivate_in_program!(users(:ram))
      end
    end

    recent_activity = RecentActivity.last
    assert_equal student, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::USER_ACTIVATION, recent_activity.action_type
    assert_nil recent_activity.for
    assert_equal RecentActivityConstants::Target::ADMINS, recent_activity.target
    assert_equal [student.program], recent_activity.programs
    assert_equal users(:ram), recent_activity.get_user(student.program)

    assert_difference('RecentActivity.count', -2) do
      student.destroy
    end
  end

  def test_suspend_from_program
    RecentActivity.destroy_all
    mentor = users(:robert)
    number_of_emails = get_pending_requests_and_offers_count(mentor) + 1

    assert_difference('ActionMailer::Base.deliveries.size', number_of_emails) do
      assert_difference('RecommendationPreference.count', -1) do
        assert_difference('RecentActivity.count') do
          mentor.suspend_from_program!(users(:f_admin), "Abuse")
        end
      end
    end
    assert_equal mentor.state_change_reason, "Abuse"
    assert_equal users(:f_admin), mentor.state_changer
    assert mentor.suspended?

    recent_activity = RecentActivity.last
    assert_equal mentor, recent_activity.ref_obj
    assert_equal RecentActivityConstants::Type::USER_SUSPENSION, recent_activity.action_type
    assert_nil recent_activity.for
    assert_equal RecentActivityConstants::Target::ADMINS, recent_activity.target
    assert_equal [mentor.program], recent_activity.programs
    assert_equal users(:f_admin), recent_activity.get_user(mentor.program)

    assert_difference('RecentActivity.count', -1) do
      mentor.destroy
    end
  end

  def test_suspend_user_who_has_group
    group = groups(:mygroup)
    student = group.students[0]

    # Two notifications are sent:
    # 1. Mail to student that he has been suspended (Immediate)
    # 2. Notification to his mentor that the student can't participate in any discussion anymore (Pending)
    assert_pending_notifications do
      assert_difference('ActionMailer::Base.deliveries.size') do
        student.suspend_from_program!(users(:f_admin), "Abuse")
      end
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal email.to.first, student.email
    assert_equal email.subject, "Your membership has been deactivated"

    notif = PendingNotification.last
    assert_equal notif.action_type, RecentActivityConstants::Type::USER_SUSPENSION
    assert_equal notif.ref_obj_creator.user, group.mentors[0]
  end

  def test_suspend_user_with_pending_offers_and_requests
    mentor = users(:f_mentor)
    student = users(:f_student)
    create_mentor_offer
    received_mentor_requests = MentorRequest.where(id: mentor.pending_received_mentor_requests.pluck(:id))
    received_meeting_requests = MeetingRequest.where(id: mentor.pending_received_meeting_requests.pluck(:id))
    received_mentor_offers = MentorOffer.where(id: student.pending_received_mentor_offers.pluck(:id))
    reason = "Test reason"

    student.suspend_from_program!(users(:f_admin), reason)
    mentor_offer_status_after_suspension = received_mentor_offers.reload.pluck(:status).uniq
    assert mentor_offer_status_after_suspension.length, 1
    assert mentor_offer_status_after_suspension.first, MentorOffer::Status::CLOSED
    mentor_offer_response_text_after_suspension = received_mentor_offers.pluck(:response).uniq
    assert mentor_offer_response_text_after_suspension.length, 1
    assert mentor_offer_response_text_after_suspension.first, "Student is no longer available"

    mentor.suspend_from_program!(users(:f_admin), reason)
    meeting_request_status_after_suspension = received_meeting_requests.reload.pluck(:status).uniq
    mentor_request_status_after_suspension = received_mentor_requests.reload.pluck(:status).uniq
    assert meeting_request_status_after_suspension.length, 1
    assert meeting_request_status_after_suspension.first, AbstractRequest::Status::CLOSED
    assert mentor_request_status_after_suspension.length, 1
    assert mentor_request_status_after_suspension.first, AbstractRequest::Status::CLOSED
    mentor_request_response_text_after_suspension = received_mentor_requests.pluck(:response_text).uniq
    assert mentor_request_response_text_after_suspension.length, 1
    assert mentor_request_response_text_after_suspension.first, "Mentor is no longer available"
    meeting_request_response_text_after_suspension = received_meeting_requests.pluck(:response_text).uniq
    assert meeting_request_response_text_after_suspension.length, 1
    assert meeting_request_response_text_after_suspension.first, "Mentor is no longer available"
  end

  def test_destroy_only_user_makes_member_dormant
    c_id = members(:student_11)
    assert members(:student_11).active?
    assert_equal 1, members(:student_11).users.size
    assert_no_difference "Member.count" do
      assert_difference "User.count", -1 do
        users(:student_11).destroy
      end
    end
    assert Member.find_by(id: c_id).dormant?
  end

  def test_destroy_only_user_in_standalone_organization
    Organization.any_instance.stubs(:standalone?).returns(true)
    user = users(:student_11)
    member = user.member

    assert member.active?
    assert_equal 1, member.users.size
    assert_difference "Member.count", -1 do
      assert_difference "User.count", -1 do
        user.destroy
      end
    end
  end

  def test_donot_destroy_member
    c_id = members(:f_student).id
    assert_equal 3, members(:f_student).reload.users.size

    assert_no_difference "Member.count" do
      assert_difference "User.count", -1 do
        users(:f_student).destroy
      end
    end
    assert_equal 2, Member.find_by(id: c_id).reload.users.size
  end

  def test_membership_request_gets_deleted_with_corresponding_user
    user = users(:f_student)
    membership_request = membership_requests(:membership_request_10)
    membership_request.update_attribute(:member_id, user.member_id)

    membership_request_2 = membership_requests(:membership_request_11)
    membership_request_2.update_attribute(:member_id, user.member_id)
    membership_request_2.update_attribute(:program_id, programs(:nwen).id)

    assert_difference "MembershipRequest.count", -1 do
      assert_difference "User.count", -1 do
        user.destroy
      end
    end

    assert_record_not_found { membership_request.reload }
    assert_nothing_raised { membership_request_2.reload }
  end

  #destroy the ra if its published in only this program
  def test_destroy_ra_user_destroy
    self.expects(:program_view?).at_least(0).returns(true)
    allow_one_to_many_mentoring_for_program(programs(:albers))
    g = groups(:mygroup)
    old_members_by_role = g.members_by_role
    mentors = ([users(:f_mentor_student)] + g.mentors - [users(:f_mentor)])
    students = g.students
    mem = users(:f_mentor).member
    assert_equal 4, mem.users.size
    g.update_members(mentors, students)

    assert_difference('RecentActivity.count', 2) do
      Group.create_ra_and_notify_members_about_member_update(g.id, old_members_by_role)
    end
    ra = RecentActivity.last

    #now if the user is removed from the program, the ra should also get deleted
    assert_difference "User.count", -1 do
      assert_difference('RecentActivity.count', -1) do
        users(:f_mentor).destroy
      end
    end
    ra1 = RecentActivity.last
    assert_false (ra==ra1)
    mem.reload
    assert_equal 3, mem.users.size
  end

  #don't destroy the ra but destroy only the program activity if its published in multiple programs
  def test_destroy_only_pa_and_not_ra_user_destroy
    mem = users(:f_mentor).member
    assert_equal 4, mem.users.size
    users(:f_mentor_nwen_student).add_role(RoleConstants::MENTOR_NAME)
    assert_difference('Article.count') do
      assert_difference('Article::Publication.count', 4) do
        assert_difference 'RecentActivity.count' do
          create_article(:author => mem, :published_programs => [programs(:albers), programs(:pbe), programs(:nwen), programs(:moderated_program)])
        end
      end
    end

    ra = RecentActivity.last
    assert_equal 4, ra.program_activities.size

    #now if the user is removed from the program, the ra should still exist but corresponding program activity should have been removed
    assert_difference "User.count", -1 do
      assert_no_difference('RecentActivity.count') do
        users(:f_mentor).destroy
      end
    end
    ra1 = RecentActivity.last
    assert (ra==ra1)
    assert_equal 3, ra.reload.program_activities.size
    mem.reload
    assert_equal 3, mem.users.size
  end

  def test_after_create
    assert_difference('RecentActivity.count') do
      @complete_user = create_user(:email => 'mentor0_sarat@chronus.com', :role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers))
    end

    assert_equal User::Status::ACTIVE, @complete_user.state
    create_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => ["Abc", "Def"], :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    create_question(:question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => ["klm", "Def"], :role_names => [RoleConstants::STUDENT_NAME])
    assert_no_difference('RecentActivity.count') do
      @incomplete_user = create_user(:email => 'mentor_sarat@chronus.com', :role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers))
    end

    assert @incomplete_user.profile_pending?

    # No recent activity for student creation.
    assert_no_difference('RecentActivity.count') do
      @student = create_user(:email => 'student_sarat@chronus.com', :role_names => [RoleConstants::STUDENT_NAME], :program => programs(:albers))
    end

    assert_equal User::Status::ACTIVE,  @student.state
    u_admin = create_user(:email => 'admin_sarat@chronus.com',:role_names => [RoleConstants::ADMIN_NAME], :program => programs(:albers))
    assert_equal [], u_admin.program.role_questions_for(RoleConstants::ADMIN_NAME).required
    assert_equal User::Status::ACTIVE,  u_admin.state
  end

  def test_mails_on_create
    program = programs(:albers)
    admin = users(:f_admin)
    assert_emails do
      create_user(:email => 'student_sarat@chronus.com', :role_names => [RoleConstants::MENTOR_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, Freakin Admin (Administrator) invites you to join as a mentor!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    assert_emails do
      create_user(:email => 'student_sarat1@chronus.com', :role_names => [RoleConstants::STUDENT_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, #{users(:f_admin).name} invites you to join as a student!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    assert_emails do
      create_user(:email => 'student_sarat2@chronus.com', :role_names => [RoleConstants::ADMIN_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "#{users(:f_admin).name} invites you to be an administrator!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    assert_emails do
      create_user(:email => 'student_sarat3@chronus.com', :role_names => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, #{admin.name} invites you to join as a Mentor and Student!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    assert_emails do
      create_user(:email => 'student_sara4@chronus.com', :role_names => [RoleConstants::ADMIN_NAME, RoleConstants::STUDENT_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, #{admin.name} invites you to join as an Administrator and Student!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    assert_emails do
      create_user(:email => 'student_sarat5@chronus.com', :role_names => [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, #{admin.name} invites you to join as an Administrator and Mentor!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    assert_emails do
      create_user(:email => 'student_sarat6@chronus.com', :role_names => [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, #{admin.name} invites you to join as an Administrator, Mentor and Student!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))

    manage_role = create_role(:name => 'manager')
    program.roles.reload
    assert_emails do
      create_user(:email => 'student_sarat7@chronus.com', :role_names => ["manager"], :program => program, :created_by => admin)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal "first_name, #{admin.name} invites you to join as a Manager!", email.subject
    assert_no_match(/Please review and publish your profile./, get_text_part_from(email).gsub("\n", " "))
    assert_match "/contact_admin", get_html_part_from(email)
    assert_match "If you have any questions, please contact the", get_html_part_from(email)
    assert_match "Accept and sign-up", get_html_part_from(email)
    assert_match "It is important that you review and complete your profile. A detailed profile helps find better matches in the program", get_html_part_from(email)
  end

  def test_after_update_for_pending_user_should_not_create_recent_activity_for_student
    create_question(program: programs(:ceg), question_type: CommonQuestion::Type::MULTI_CHOICE, question_choices: "klm, Def", role_names: [RoleConstants::STUDENT_NAME], required: true)
    m1 = programs(:ceg).build_and_save_user!({}, [RoleConstants::STUDENT_NAME], members(:f_student))
    assert m1.profile_pending?
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference('RecentActivity.count') do
        m1.update_attribute(:state, User::Status::ACTIVE)
      end
    end
  end

  def test_for_no_recent_activity_on_user_deletion
    user = users(:f_mentor)
    user.destroy
    assert_nothing_raised do
      assert_no_emails do
        assert_no_difference('RecentActivity.count') do
          UserObserver.recent_activity_for_user_state_change_by_id(user.id, RecentActivityConstants::Type::USER_ACTIVATION, RecentActivityConstants::Target::ADMINS)
        end
      end
    end
  end

  def test_after_update_for_pending_user_should_create_recent_activity_for_mentor
    q3 = create_question(:program => programs(:ceg), :question_type => CommonQuestion::Type::MULTI_CHOICE, :question_choices => "klm, Def", :role_names => [RoleConstants::MENTOR_NAME], :required => true)
    m1 = programs(:ceg).build_and_save_user!({}, [RoleConstants::MENTOR_NAME], members(:f_student))
    assert m1.profile_pending?
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      assert_difference('RecentActivity.count') do
        m1.update_attribute(:state, User::Status::ACTIVE)
      end
    end
  end

  def test_create_when_a_admin_adds_a_mentor
    create_question(
      :program => programs(:albers),
      :question_type => CommonQuestion::Type::MULTI_CHOICE,
      :question_choices => "klm, Def",
      :role_names => [RoleConstants::MENTOR_NAME],
      :required => true)

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference('RecentActivity.count') do
        assert_difference 'User.count' do
          @user = create_user(:email => 'student_sarat@chronus.com', :role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers), :created_by => users(:f_admin))
        end
      end
    end

    assert @user.profile_pending?
  end

  def test_create_when_a_admin_adds_a_mentee
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference('Password.count') do
        assert_no_difference('RecentActivity.count') do
          assert_difference 'User.count' do
            @user = create_user(:email => 'student_sarat@chronus.com', :role_names => [RoleConstants::STUDENT_NAME], :program => programs(:albers), :created_by => users(:f_admin))
          end
        end
      end
    end
    assert @user.active?
  end

  def test_create_when_a_admin_adds_a_mentee_and_a_mentor
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference('Password.count') do
        assert_difference 'User.count' do
          @user = create_user(:email => 'user@chronus.com', :role_names => [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME], :program => programs(:albers), :created_by => users(:f_admin))
        end
      end
    end
    assert @user.is_mentor_or_student?
    assert @user.active?
  end

  def test_send_user_suspension_emails
    group = groups(:mygroup)
    student = group.students.first
    mentor = group.mentors.first
    mentor_membership = group.membership_of(mentor)
    admin_user = group.program.admin_users.first
    student.update_attribute(:state_changer_id, admin_user.id)
    mentor.update_attribute(:state_changer_id, admin_user.id)

    assert_emails do
      assert_difference "JobLog.count", 2 do
        assert_pending_notifications do
          assert_nothing_raised do
            UserObserver.send_user_suspension_emails(student, JobLog.generate_uuid)
          end
        end
      end
    end
    job_log = JobLog.last
    pending_notification = PendingNotification.last
    assert_equal mentor_membership, job_log.ref_obj
    assert_equal mentor_membership, pending_notification.ref_obj_creator
    assert_equal student, pending_notification.ref_obj
    assert_equal RecentActivityConstants::Type::USER_SUSPENSION, pending_notification.action_type

    group.auto_terminate_due_to_inactivity!
    assert_emails do
      assert_difference "JobLog.count", 1 do
        assert_no_difference "PendingNotification.count" do
          assert_nothing_raised do
            UserObserver.send_user_suspension_emails(mentor, JobLog.generate_uuid)
          end
        end
      end
    end
  end

  def test_send_user_no_suspension_emails
    user = users(:f_mentor)
    user.destroy
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        assert_nothing_raised do
          UserObserver.send_user_suspension_emails_by_id(user.id)
        end
      end
    end
  end

  def test_user_destroy_removes_member_meeting
    user = users(:f_mentor)
    time = Time.now.change(:usec => 0)
    meeting = create_meeting(
      :recurrent        => true,
      :repeat_every     => 1,
      :schedule_rule    => Meeting::Repeats::DAILY,
      :members          => [members(:f_admin), user.member],
      :owner_id         => user.member.id,
      :program_id       => user.program.id,
      :repeats_end_date => time + 2.days,
      :start_time       => time,
      :end_time         => time + 5.hours
    )
    member_meeting = meeting.member_meetings.find_by(member_id: user.member)
    user.destroy
    assert !MemberMeeting.exists?(member_meeting.id)
  end

  def test_user_destroy_removes_member_meeting_for_dormant_user
    user = users(:student_11)
    user_member = members(:student_11)
    time = Time.now.change(:usec => 0)
    meeting = create_meeting(
      :recurrent        => true,
      :repeat_every     => 1,
      :schedule_rule    => Meeting::Repeats::DAILY,
      :members          => [members(:f_admin), user_member],
      :owner_id         => user_member.id,
      :program_id       => user.program.id,
      :repeats_end_date => time + 2.days,
      :start_time       => time,
      :end_time         => time + 5.hours
    )
    member_meeting = meeting.member_meetings.find_by(member_id: user_member)
    assert user_member.active?
    assert_equal 1, user_member.users.size
    assert_no_difference "Member.count" do
      assert_difference "User.count", -1 do
        user.destroy
      end
    end
    assert Member.find_by(id: user.member.id).dormant?
    assert !MemberMeeting.exists?(member_meeting.id)
  end

  def test_user_destroy_removes_member_meeting_of_withdrawn_or_inactive_meetings
    meeting = create_meeting(force_non_time_meeting: true)
    mentor = meeting.owner.user_in_program(meeting.program)
    member_meeting = meeting.member_meetings.find_by(member_id: mentor.member)
    assert_difference "Meeting.count", -1 do
      meeting.false_destroy!
    end

    mentor.destroy
    assert_record_not_found do
      member_meeting.reload
    end
  end

  def test_should_cleanup_campaign_messages
    user = users(:f_admin)
    CampaignManagement::AbstractCampaignMessage.expects(:reset_sender_id_for).with(user.id).once
    assert_difference "User.count", -1 do
      user.destroy
    end
  end

  def test_add_user_mails_are_trigerred_on_import_from_other_programs
    assert_emails 1 do
      user = create_user(:email => "user1@example.com", :role_names => [RoleConstants::STUDENT_NAME], :program => programs(:albers), :created_by => users(:f_admin), :imported_from_other_program => true)
    end
    email = ActionMailer::Base.deliveries.last
    assert_match /It is important that you review and complete your profile. A detailed profile helps find better matches in the program/, get_html_part_from(email)

    assert_emails 1 do
      create_user(:email => "user2@example.com", :role_names => [RoleConstants::MENTOR_NAME], :program => programs(:albers), :created_by => users(:f_admin), :imported_from_other_program => true)
    end

    email = ActionMailer::Base.deliveries.last

    assert_match /It is important that you review and complete your profile. A detailed profile helps find better matches in the program/, get_html_part_from(email)

    assert_emails 1 do
      create_user(:email => "user3@example.com", :role_names => [RoleConstants::ADMIN_NAME, RoleConstants::MENTOR_NAME], :program => programs(:albers), :created_by => users(:f_admin), :imported_from_other_program => true)
    end
    email = ActionMailer::Base.deliveries.last

    assert_match /It is important that you review and complete your profile. A detailed profile helps find better matches in the program/, get_html_part_from(email)
  end

  def test_send_user_suspension_emails_with_job_uuid
    users(:f_mentor).state_changer_id = users(:f_admin).id
    users(:f_mentor).save!
    users(:mkr_student).state_changer_id = users(:f_admin).id
    users(:mkr_student).save!
    assert_emails 1 do
      assert_difference "JobLog.count", 2 do
        assert_pending_notifications do
          assert_nothing_raised do
            UserObserver.send_user_suspension_emails_by_id(users(:f_mentor).id, "15")
         end
        end
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        assert_pending_notifications 0 do
          assert_nothing_raised do
            UserObserver.send_user_suspension_emails_by_id(users(:f_mentor).id, "15")
          end
        end
      end
    end

    assert_emails 1 do
      assert_difference "JobLog.count", 2 do
        assert_pending_notifications do
          assert_nothing_raised do
            UserObserver.send_user_suspension_emails_by_id(users(:mkr_student).id, "16")
          end
        end
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        assert_pending_notifications 0 do
          assert_nothing_raised do
            UserObserver.send_user_suspension_emails_by_id(users(:mkr_student).id, "16")
          end
        end
      end
    end
  end

  # Career Dev Portal Related Tests

  def test_mails_on_import_from_other_programs_to_portal
    assert_emails 1 do
      user = create_user(:email => 'user1@chronus.com', :role_names => [RoleConstants::EMPLOYEE_NAME], :program => programs(:primary_portal), :created_by => users(:portal_admin), :imported_from_other_program => true)
    end
    email = ActionMailer::Base.deliveries.last
    assert_match(/You have been added as an Employee in Primary Career Portal/, get_text_part_from(email).gsub("\n", " "))
    assert_match(/to visit Primary Career Portal/, get_text_part_from(email).gsub("\n", " "))

    assert_emails 1 do
      create_user(:email => 'user2@chronus.com', :role_names => [RoleConstants::ADMIN_NAME], :program => programs(:primary_portal), :created_by => users(:portal_admin), :imported_from_other_program => true)
    end
    email = ActionMailer::Base.deliveries.last
    assert_match(/You have been added as an Administrator in Primary Career Portal/, get_text_part_from(email).gsub("\n", " "))
    assert_match(/to visit Primary Career Portal/, get_text_part_from(email).gsub("\n", " "))

    assert_emails 1 do
      create_user(:email => 'user3@chronus.com', :role_names => [RoleConstants::ADMIN_NAME, RoleConstants::EMPLOYEE_NAME], :program => programs(:primary_portal), :created_by => users(:portal_admin), :imported_from_other_program => true)
    end
    email = ActionMailer::Base.deliveries.last
    assert_match(/You have been added as an Administrator and Employee in Primary Career Portal/, get_text_part_from(email).gsub("\n", " "))
    assert_match(/to visit Primary Career Portal/, get_text_part_from(email).gsub("\n", " "))
  end

  def test_on_destroying_portal_user_should_not_call_for_reindexing_matches
    user = users(:portal_employee)
    Matching.expects(:remove_user).never
    user.destroy
  end
end
