require_relative './../test_helper.rb'

class MemberTest < ActiveSupport::TestCase
  include Geokit::Geocoders

  #-----------------------------------------------------------------------------
  # VALIDATIONS
  #-----------------------------------------------------------------------------

  def test_required_fields
    member = Member.new(state: nil, organization: programs(:org_primary))
    assert_false member.valid?
    assert member.errors[:organization]
    assert member.errors[:state]
    assert member.errors[:email]
    assert_blank member.errors[:password]
    assert_blank member.errors[:password_confirmation]
    assert member.errors[:last_name]
    assert member.errors[:first_name]
  end

  def test_password_cannot_be_blank_when_required_password_is_set
    member = Member.new(state: nil, validate_password: true, organization: programs(:org_primary))
    assert_false member.valid?
    assert member.errors[:password]
    assert member.errors[:password_confirmation]
  end

  def test_password_cannot_be_blank_on_update_for_chronus_auth
    member = create_member

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :password do
      member.password = ""
      member.password_confirmation = ""
      member.save!
    end
  end

  def test_should_not_create_a_member_with_invalid_name
    member = programs(:org_primary).members.new
    member.email = "a@gmail.com"
    member.password = "monkey"
    member.password_confirmation = "monkey"
    member.last_name = ""
    member.first_name = ""
    assert_false member.valid?
    assert_equal ["can't be blank", "is too short (minimum is 1 character)"], member.errors[:last_name]
    assert_equal ["can't be blank"], member.errors[:first_name]

    member.last_name = 'ab' * 100
    member.first_name = 'ab' * 100
    assert_false member.valid?
    assert_equal ["is too long (maximum is 100 characters)"], member.errors[:last_name]
    assert_equal ["is too long (maximum is 100 characters)"], member.errors[:first_name]
  end

  def test_should_not_create_a_member_with_bad_email
    e = assert_raise(ActiveRecord::RecordInvalid) do
      member = programs(:org_primary).members.new
      member.email = ".aobad@gmail.com"
      member.password = "monkey"
      member.password_confirmation = "monkey"
      member.last_name = "Email"
      member.first_name = "Weird"
      member.save!
    end

    assert_match(/Email is not a valid email address/, e.message)
  end

  def test_email_should_have_valid_format_ignore_domain
    member = members(:f_student)
    member.email = "balaji@domaindoesnotexists.com"
    assert member.save

    member.email = "invalid.formate.email"
    assert_false member.save
    assert_equal ["is not a valid email address."], member.errors.messages[:email]
  end

  def test_should_edit_a_member_with_blank_first_name
    member = members(:f_mentor)
    member.first_name = ""
    assert member.valid?
  end

  def test_set_remember_token
    members(:ram).remember_me
    assert_not_nil members(:ram).remember_token
    assert_not_nil members(:ram).remember_token_expires_at
  end

  def test_unset_remember_token
    members(:ram).remember_me
    assert_not_nil members(:ram).remember_token
    members(:ram).forget_me
    assert_nil members(:ram).remember_token
  end

  def test_remembers_me_for_one_week
    member = members(:ram)
    Timecop.freeze do
      member.remember_me_for 1.week
      assert_not_nil member.remember_token
      assert_equal 1.week.from_now.change(usec: 0), member.remember_token_expires_at
    end
  end

  def test_remembers_me_until_one_week
    member = members(:ram)
    time = 1.week.from_now
    member.remember_me_until time
    assert_not_nil member.remember_token
    assert_equal time.change(usec: 0), member.remember_token_expires_at
  end

  def test_remembers_me_default_two_weeks
    member = members(:ram)
    Timecop.freeze do
      member.remember_me
      assert_not_nil member.remember_token
      assert_equal 2.weeks.from_now.change(usec: 0), member.remember_token_expires_at
    end
  end

  def test_state_validations
    member = members(:f_mentor)
    assert member.active?
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :state do
      member.update_attributes!(state: 4)
    end
  end

  def test_check_dormant_state
    member = create_member(state: Member::Status::DORMANT)
    assert member.dormant?
    member.update_attribute(:state, Member::Status::ACTIVE)
    assert_false member.dormant?
  end

  def test_admin_only_at_track_level
    member = members(:ram)

    member.stubs(:admin?).returns(true)
    assert_false member.admin_only_at_track_level?

    member.stubs(:admin?).returns(false)
    member.stubs(:track_level_admin?).returns(false)
    assert_false member.admin_only_at_track_level?

    member.stubs(:track_level_admin?).returns(true)
    assert member.admin_only_at_track_level?
  end

  def test_track_level_admin
    member = members(:ram)

    member.stubs(:managing_programs).returns(["a", "b"])
    assert member.track_level_admin?

    member.stubs(:managing_programs).returns([])
    assert_false member.track_level_admin?
  end

  def test_managing_programs
    member = members(:f_admin)
    assert_equal 4, member.managing_programs.count
    assert_equal_unordered member.managing_programs.pluck(:id).uniq, member.managing_programs(ids_only: true)
  end

  def test_programs_to_add_users
    member = members(:f_admin)
    organization = member.organization
    assert_equal_unordered organization.program_ids, member.programs_to_add_users.collect(&:id)

    member = members(:f_student)
    member.stubs(:managing_programs).returns(Program.first(3))
    User.any_instance.stubs(:import_members_from_subprograms?).returns(true)
    
    assert_equal_unordered organization.program_ids, member.programs_to_add_users.collect(&:id)

    User.any_instance.stubs(:import_members_from_subprograms?).returns(false)

    assert_equal_unordered Program.first(3).collect(&:id), member.programs_to_add_users.collect(&:id)
  end

  def test_uniqueness_of_email_in_an_organization
    assert Member.exists?(email: members(:ram).email, organization_id: programs(:org_primary).id)

    member = programs(:org_primary).members.new
    member.email = members(:ram).email
    assert_false member.valid?
    assert_equal ["has already been taken"], member.errors[:email]
  end

  def test_email_with_whitespace_in_an_organization
    member = programs(:org_primary).members.new
    member.email = 'abcd@gmail.com  '
    member.first_name = "India"
    member.last_name = "Pakistan"
    assert member.valid?

    assert Member.exists?(email: members(:ram).email, organization_id: programs(:org_primary).id)

    member = programs(:org_primary).members.new
    member.email = members(:ram).email + '  '
    assert_false member.valid?
    assert_equal ["has already been taken"], member.errors[:email]
  end

  def test_create_success_for_email_with_special_characters
    assert_difference "Member.count" do
      @member = create_member(organization: programs(:org_anna_univ), email: "spe_c'ial.email@gmail.com")
    end

    assert_equal programs(:org_anna_univ), @member.organization
    assert_equal "spe_c'ial.email@gmail.com", @member.email
  end

  def test_mentoradmin
    member = members(:f_admin)
    assert_false member.mentoradmin?
    member.email = SUPERADMIN_EMAIL
    assert member.mentoradmin?
  end

  def test_check_indigenous_login_identifier
    member = members(:f_admin)
    organization = member.organization
    member.login_identifiers.destroy_all
    assert_false member.valid?
    assert_equal ["is invalid"], member.errors[:password]

    member.login_identifiers.create!(auth_config_id: organization.linkedin_oauth.id, identifier: "uid")
    assert_false member.valid?

    member.login_identifiers.create!(auth_config_id: organization.chronus_auth.id)
    assert member.valid?
  end

  def test_create_success
    organization = programs(:org_anna_univ)
    assert_difference "Member.count" do
      @member = create_member(organization: organization)
    end
    assert_equal organization, @member.organization
  end

  #-----------------------------------------------------------------------------
  # ASSOCIATIONS
  #-----------------------------------------------------------------------------

  def test_has_many_users
    assert_equal_unordered [users(:ceg_mentor), users(:psg_mentor)], members(:anna_univ_mentor).users
  end

  def test_has_many_roles
    member = members(:anna_univ_mentor)
    assert_equal [fetch_role(:psg, :mentor), fetch_role(:ceg, :mentor)], member.roles
    users(:ceg_mentor).add_role('student')
    users(:ceg_mentor).reload
    assert users(:ceg_mentor).is_mentor_and_student?
    member.reload
    assert_equal [fetch_role(:psg, :mentor), fetch_role(:ceg, :mentor), fetch_role(:ceg, :student)], member.roles
  end

  def test_role_helpers
    member = members(:anna_univ_mentor)
    assert member.is_mentor?
    assert_false member.is_student?
    users(:ceg_mentor).add_role(RoleConstants::STUDENT_NAME)
    member.reload
    users(:ceg_mentor).reload

    assert member.is_mentor?
    assert member.is_student?
    assert member.is_mentor_and_student?
  end

  def test_has_many_managees
    assert_equal members(:rahim).managees, [members(:student_1)]
  end

  def test_has_many_content_updated_emails
    member = members(:f_admin)
    user = users(:f_admin)
    program = user.program
    organization = member.organization
    assert_empty member.content_updated_emails
    program_mailer_template = program.mailer_templates.first
    program_mailer_template.update_attributes!(content_changer_member_id: member.id)
    org_mailer_template = organization.mailer_templates.create!(uid: "ezkgp8mo", subject: "Test", source: "Test", content_changer_member_id: member.id)

    content_updated_email_ids = member.content_updated_email_ids
    assert_equal 2, content_updated_email_ids.size
    assert_no_difference "Mailer::Template.count" do # No dependent destroy
      assert_difference "Member.count", -1 do
        member.destroy
      end
    end
    assert_equal [nil], Mailer::Template.where(id: content_updated_email_ids).pluck(:content_changer_member_id).uniq
  end

  def test_picture_url
    member = members(:f_mentor)
    # When no picture
    assert_nil member.profile_picture
    assert_equal UserConstants::DEFAULT_PICTURE[:small], member.picture_url(:small)
    assert_equal UserConstants::DEFAULT_PICTURE[:large], member.picture_url(:large)

    # When picture is present
    member.profile_picture = ProfilePicture.new(
      image: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    )
    member.save!
    member.reload
    assert_not_nil member.profile_picture
    assert_equal member.profile_picture.image.url(:small), member.picture_url(:small)
    assert_equal member.profile_picture.image.url(:medium), member.picture_url(:medium)

    # When picture not applicable
    member.profile_picture.destroy
    assert_nil member.reload.profile_picture
    ProfilePicture.create!(member: member, image: nil, not_applicable: true)
    assert_equal UserConstants::DEFAULT_PICTURE[:small], member.picture_url(:small)
    assert_equal UserConstants::DEFAULT_PICTURE[:large], member.picture_url(:large)
  end

  def test_member_picture_path_for_pdf
    member = members(:f_mentor)
    assert_equal UserConstants::DEFAULT_PICTURE[:medium], member.picture_path_for_pdf(:medium)
    ProfilePicture.create(
      member: members(:f_mentor),
      image: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    )
    assert members(:f_mentor).reload.profile_picture
    assert_equal member.picture_url(:medium), member.picture_path_for_pdf(:medium)
  end

  def test_has_many_meetings
    member = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)
    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    member_meeting = member_meetings(:member_meetings_1)
    daily_member_meeting = member_meetings(:member_meetings_11)

    assert member.is_attending?(meeting, meeting.start_time)
    assert_equal [member_meeting, daily_member_meeting, meetings(:upcoming_calendar_meeting).member_meetings.where(member_id: members(:f_mentor).id).first, meetings(:past_calendar_meeting).member_meetings.where(member_id: members(:f_mentor).id).first, meetings(:completed_calendar_meeting).member_meetings.where(member_id: members(:f_mentor).id).first, meetings(:cancelled_calendar_meeting).member_meetings.where(member_id: members(:f_mentor).id).first], member.member_meetings
    assert_equal [meeting, daily_meeting, meetings(:upcoming_calendar_meeting), meetings(:past_calendar_meeting), meetings(:completed_calendar_meeting), meetings(:cancelled_calendar_meeting)], member.meetings
  end

  def test_login_token_association
    member = members(:f_mentor)
    login_tokens = [login_tokens(:login_token_1), login_tokens(:login_token_3)]
    assert_equal_unordered login_tokens, member.login_tokens
    member = create_member
    token = create_login_token(member: member)
    assert_equal [token], member.login_tokens
    assert_difference "LoginToken.count", -1 do
      assert_difference "Member.count", -1 do
        member.destroy
      end
    end
  end

  #-----------------------------------------------------------------------------
  # CONNECTION
  #-----------------------------------------------------------------------------

  def test_my_students
    mentor = users(:mentor_5)
    member = mentor.member
    assert mentor.students.empty? # No students yet for the mentor

    assigned_students = []

    5.upto(14) do |i|
      student = users("student_#{i}".to_sym)

      if i % 2 == 0
        # Create a group with the given mentor and student.
        create_group(mentor: mentor, students: [student], program: programs(:albers))

        assigned_students << student.member
      end
    end

    assert_equal assigned_students.size, member.reload.mentoring_groups.size
    assert_equal_unordered assigned_students, member.students
    assert_equal_unordered assigned_students, member.students(:active)
    assert_equal_unordered assigned_students, member.students(:all)
    assert_equal [], member.students(:closed)

    group_to_terminate = mentor.mentoring_groups.first
    group_to_terminate.terminate!(users(:f_admin), "Test reason", group_to_terminate.program.permitted_closure_reasons.first.id)
    updated_students = assigned_students - group_to_terminate.students.collect(&:member)

    assert_equal assigned_students.size, member.reload.mentoring_groups.count
    assert_equal assigned_students.size - 1, member.reload.mentoring_groups.active.count
    assert_equal_unordered updated_students, member.students
    assert_equal_unordered updated_students, member.students(:active)
    assert_equal_unordered assigned_students, member.students(:all)
    assert_equal group_to_terminate.students.collect(&:member), member.students(:closed)
  end

  def test_my_students_for_a_mentor_mentee_user
    mentor_student = users(:mentor_7)
    mentor_student.add_role(RoleConstants::STUDENT_NAME)
    assert mentor_student.is_mentor_and_student?

    member = mentor_student.member
    assert mentor_student.students.empty? # No students yet for the mentor
    mentor_student.update_attribute :max_connections_limit, 10

    assigned_students = []

    5.upto(14) do |i|
      student = users("student_#{i}".to_sym)

      if i % 2 == 0
        # Create a group with the given mentor and student.
        create_group(mentor: mentor_student, students: [student], program: programs(:albers))

        assigned_students << student.member
      end
    end

    8.upto(10) do |i|
      create_group(
        mentor: users("mentor_#{i}".to_sym),
        students: [mentor_student],
        program: programs(:albers))
    end

    assert_equal_unordered assigned_students, member.reload.students
  end

  # Member#mentors should return the mentors of the student via his group(s).
  def test_my_mentors
    student = users(:student_10)
    assert student.mentors.empty? # No mentor yet for the student
    member = student.member

    mentors = []

    5.upto(14) do |i|
      mentor = users("mentor_#{i}".to_sym)

      if i % 2 == 0
        # Create a group with the given mentor and student.
        create_group(mentor: mentor, students: [student], program: programs(:albers))

        mentors << mentor.member
      end
    end

    assert_equal mentors.size, member.reload.studying_groups.size
    assert_equal_unordered mentors, member.mentors
    assert_equal_unordered mentors, member.mentors(:active)
    assert_equal_unordered mentors, member.mentors(:all)
    assert_equal [], member.mentors(:closed)

    group_to_terminate = student.studying_groups.first
    group_to_terminate.terminate!(users(:f_admin), "Test reason", group_to_terminate.program.permitted_closure_reasons.first.id)
    updated_mentors = mentors - group_to_terminate.mentors.collect(&:member)

    assert_equal 5, member.reload.studying_groups.count
    assert_equal 4, member.studying_groups.active.count
    assert_equal_unordered updated_mentors, member.mentors
    assert_equal_unordered updated_mentors, member.mentors(:active)
    assert_equal_unordered mentors, member.mentors(:all)
    assert_equal group_to_terminate.mentors.collect(&:member), member.mentors(:closed)
  end

  #-----------------------------------------------------------------------------
  # PROFILE
  #-----------------------------------------------------------------------------

  def test_answer_for
    prog_q = create_question(
      role_names: [RoleConstants::MENTOR_NAME],
      program: programs(:albers))

    member = Member.includes(:profile_answers).find(3)
    assert_nil member.answer_for(prog_q)
    assert_equal profile_answers(:one), member.answer_for(profile_questions(:string_q))

    a1 = ProfileAnswer.create!(profile_question: prog_q, answer_text: "Whatever", ref_obj: member)
    assert_equal a1, member.answer_for(prog_q)
  end

  def test_promote_and_demote_admin
    member = members(:f_mentor)
    user = users(:f_mentor)
    suspended_member = members(:inactive_user)
    suspended_user = users(:inactive_user)

    assert_false member.admin?
    assert_false user.is_admin?
    assert_false suspended_member.admin?
    assert_false suspended_user.is_admin?

    n_programs_member_not_in = member.organization.programs.size - member.users.size
    assert (n_programs_member_not_in > 0)
    n_programs_suspended_member_not_in = suspended_member.organization.programs.size - suspended_member.users.size
    assert (n_programs_suspended_member_not_in > 0)

    assert_difference "User.count", n_programs_member_not_in do
      member.promote_as_admin!
      suspended_member.promote_as_admin!
    end
    assert member.admin?
    assert user.reload.is_admin?
    assert suspended_member.suspended?
    assert_false suspended_member.admin?
    assert_false suspended_user.reload.is_admin?

    # Demoting a member should not affect the admin status of the users in the programs.
    member.demote_from_admin!
    assert_false member.admin?
    assert user.reload.is_admin?
  end

  #-----------------------------------------------------------------------------
  # GROUPED RECENT ACTIVITY FEED
  #-----------------------------------------------------------------------------

  def test_activities_to_show
    member = members(:anna_univ_mentor)
    assert member.activities_to_show.empty?
    p1 = programs(:ceg)
    p2 = programs(:psg)
    create_announcement(program: p1, admin: users(:ceg_admin), recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name))
    create_announcement(program: p2, admin: users(:psg_admin), recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name))

    activities = []

    RecentActivity.destroy_all
    0.upto(4) do |i|
      show_p1 = rand(2) == 0
      activities << RecentActivity.create!(
        programs: [show_p1 ? p1 : p2],
        action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        target: RecentActivityConstants::Target::MENTORS,
        created_at: i.days.ago,
        ref_obj: announcements(:assemble))
    end

    assert_equal activities.reverse, member.activities_to_show

    memb = members(:f_admin)
    pub_prog = [programs(:albers), programs(:nwen)]
    create_article(author: memb, published_programs: pub_prog)

    # article activity is no longer shown at org level!
    assert_equal 0, memb.activities_to_show.size
  end

  def test_activities_to_show_doesnt_fetch_activities_targeted_at_none
    a1 = create_announcement(
      program: programs(:moderated_program),
      recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name))
    RecentActivity.destroy_all

    assert_difference "RecentActivity.count", 2 do
      @ra1 = RecentActivity.create!(
        programs: [programs(:moderated_program)],
        action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        target: RecentActivityConstants::Target::NONE,
        ref_obj: a1
      )

      @ra2 = RecentActivity.create!(
        programs: [programs(:moderated_program)],
        action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
        target: RecentActivityConstants::Target::ALL,
        ref_obj: a1
      )
    end

    assert_equal [@ra2], members(:moderated_student).activities_to_show
    assert_equal [@ra2], members(:moderated_mentor).activities_to_show
    assert_equal [@ra2], members(:moderated_admin).activities_to_show
  end

  def test_activities_to_show_fetches_only_that_are_relevant
    activities = []

    RecentActivity.destroy_all
    group = groups(:mygroup)
    group.expiry_time = group.expiry_time + 1.day
    group.save!
    activities << RecentActivity.last

    assert_equal activities, groups(:mygroup).students.first.member.activities_to_show
    assert members(:robert).activities_to_show

    RecentActivity.destroy_all
    obj_less_activity = RecentActivity.create!(
   programs: [programs(:albers)],
      action_type: RecentActivityConstants::Type::ANNOUNCEMENT_CREATION,
      target: RecentActivityConstants::Target::MENTORS
    )

    assert_nil obj_less_activity.ref_obj
    assert members(:f_mentor).activities_to_show
  end

  def test_activities_to_show_ignores_disabled_feature_activities
    activities = []

    group = groups(:mygroup)
    group.expiry_time = group.expiry_time + 1.day
    group.save!
    activities << RecentActivity.last

    grouped_activites = members(:f_mentor).activities_to_show
    assert_equal activities, grouped_activites

    RecentActivity.destroy_all

    #For creating RA
    create_qa_question(user: users(:f_mentor), program: programs(:albers))

    assert members(:f_admin).activities_to_show.any?
    o = programs(:albers).organization
    o.enable_feature(FeatureName::ANSWERS, false)
    assert !o.reload.has_feature?(FeatureName::ANSWERS)
    assert members(:f_mentor).reload.activities_to_show.empty?
  end

  def test_activities_to_show_when_user_state_not_active
    member = members(:anna_univ_mentor)
    member.users.each do |m|
      m.update_attribute :state, User::Status::PENDING
    end
    p1 = programs(:ceg)
    p2 = programs(:psg)
    create_announcement(program: p1, admin: users(:ceg_admin), recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name))
    create_announcement(program: p2, admin: users(:psg_admin), recipient_role_names: programs(:albers).roles_without_admin_role.collect(&:name))
    assert_empty member.activities_to_show
  end

  def test_admins
    assert_equal [members(:f_admin), members(:anna_univ_admin), members(:foster_admin), members(:custom_domain_admin), members(:no_subdomain_admin), members(:nch_admin)], Member.admins
  end

  def test_name_with_email
    assert_equal "Good unique name <robert@example.com>", members(:f_mentor).name_with_email
    assert_equal "Good unique name <robert@example.com>", members(:f_mentor_ceg).name_with_email
    assert_equal "Freakin Admin <fosteradmin@example.com>", members(:foster_admin).name_with_email
  end

  #-----------------------------------------------------------------------------
  # EMAIL DELIVERY
  #-----------------------------------------------------------------------------

  def test_send_email
    member = members(:f_student)
    InboxMessageNotification.expects(:inbox_message_notification).with(member, messages(:second_message), {}).returns(stub(:deliver_now))
    member.send_email(messages(:second_message), RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION)
  end

  def test_send_email_change_notification
    member = members(:f_student)
    email_changer = members(:f_admin)
    assert_emails do
      Member.send_email_change_notification(member.id, member.email, "old_email@gmail.com", email_changer.id)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal ["old_email@gmail.com"], email.to
    assert_equal "Email address successfully updated", email.subject

    assert_no_emails do
      Member.send_email_change_notification(member.id, "newest_email@gmail.com", "old_email@gmail.com", email_changer.id)
    end

    assert_no_emails do
      Member.send_email_change_notification(0, member.email, "old_email@gmail.com", email_changer.id)
    end
  end

  def test_send_email_send_now_option
    member = members(:f_student)

    InboxMessageNotification.expects(:inbox_message_notification).with(member, messages(:second_message), {}).returns(stub(:deliver_now))
    member.send_email(
      messages(:second_message),
      RecentActivityConstants::Type::INBOX_MESSAGE_NOTIFICATION)
  end

  def test_active
    assert members(:f_mentor).active?
    members(:f_mentor).update_attribute :state, Member::Status::DORMANT
    assert members(:f_mentor).active?
    members(:f_mentor).update_attribute :state, Member::Status::SUSPENDED
    assert_false members(:f_mentor).active?
  end

  def test_suspend
    member = members(:f_mentor)
    user_1 = users(:f_mentor)
    user_2 = users(:f_mentor_nwen_student)
    user_3 = users(:f_mentor_pbe)
    user_4 = users(:f_onetime_mode_mentor)
    assert user_1.active? && user_2.active? && user_3.active? && user_4.active?

    user_2.update_column(:state, User::Status::PENDING)
    suspend_user(user_4)

    options = { send_email: false, global_suspension: true }
    reason = "Suspension reason"
    User.any_instance.expects(:suspend_from_program!).with(users(:f_admin), reason, options).once
    User.any_instance.expects(:suspend_from_program!).with(users(:f_admin_nwen), reason, options).once
    User.any_instance.expects(:suspend_from_program!).with(users(:f_admin_pbe), reason, options).once
    User.any_instance.expects(:suspend_from_program!).with(users(:f_admin_moderated_program), reason, options).once

    member.reload
    member.expects(:can_be_removed_or_suspended?).returns(true)
    current_time = Time.now
    Timecop.freeze(current_time) do
      assert_emails 1 do
        member.suspend!(members(:f_admin), reason)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert member.suspended?
    assert_equal member.last_suspended_at.to_i, current_time.to_i
    assert_equal [member.email], email.to
    assert_equal "Your membership has been suspended", email.subject
  end

  def test_suspend_send_email_set_false
    member = members(:f_mentor)
    user_1 = users(:f_mentor)
    user_2 = users(:f_mentor_nwen_student)
    user_3 = users(:f_mentor_pbe)
    user_4 = users(:f_onetime_mode_mentor)
    reason = "Suspension reason"
    assert user_1.active? && user_2.active? && user_3.active? && user_4.active?
    User.any_instance.expects(:close_pending_received_requests_and_offers).times(member.users.count)

    assert_difference "UserStateChange.count", 4 do
      assert_difference "RecentActivity.count", 4 do
        assert_no_emails do
          member.suspend!(members(:f_admin), reason, false)
        end
      end
    end

    assert_no_difference "UserStateChange.count" do
      assert_no_difference "RecentActivity.count" do
        assert_no_emails do
          member.suspend!(members(:f_admin), reason)
        end
      end
    end
    assert member.suspended?
    assert user_1.reload.suspended?
    assert user_2.reload.suspended?
    assert user_3.reload.suspended?
    assert user_4.reload.suspended?
  end

  def test_suspend_members
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        Member.suspend_members([], members(:f_admin), "", JobLog.generate_uuid)
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        Member.suspend_members([members(:inactive_user).id], members(:anna_univ_admin), "", JobLog.generate_uuid)
      end
    end

    member_1 = members(:f_mentor)
    member_2 = members(:f_student)
    admin = members(:f_admin)
    members = [member_1, member_2]
	count = 0
	members.each{|m| count += m.users.count }
    User.any_instance.expects(:close_pending_received_requests_and_offers).times(count)
    assert_emails members.size do
      assert_difference "JobLog.count", members.size do
        Member.suspend_members(members.collect(&:id), admin, "", JobLog.generate_uuid)
      end
    end
    emails = ActionMailer::Base.deliveries.last(2)
    assert member_1.reload.suspended?
    assert member_2.reload.suspended?
    assert_equal_unordered [member_1.email, member_2.email], emails.collect(&:to).flatten
    assert_equal ["Your membership has been suspended"], emails.collect(&:subject).uniq
  end

  def test_reactivate
    member = members(:f_mentor)
    user_1 = users(:f_mentor)
    user_2 = users(:f_mentor_nwen_student)
    user_3 = users(:f_mentor_pbe)
    user_4 = users(:f_onetime_mode_mentor)

    member.update_column(:state, Member::Status::SUSPENDED)
    suspend_user(user_1, { track: User::Status::ACTIVE, global: User::Status::SUSPENDED })
    suspend_user(user_2, { global: User::Status::PENDING })
    suspend_user(user_3, { global: User::Status::ACTIVE })

    options = { send_email: false, global_reactivation: true }
    User.any_instance.stubs(:profile_incomplete_roles).returns([RoleConstants::MENTOR_NAME])
    User.any_instance.expects(:reactivate_in_program!).with(users(:f_admin), options).once
    User.any_instance.expects(:reactivate_in_program!).with(users(:f_admin_nwen), options).once
    User.any_instance.expects(:reactivate_in_program!).with(users(:f_admin_pbe), options).once
    User.any_instance.expects(:reactivate_in_program!).with(users(:f_admin_moderated_program), options).once

    assert_emails 1 do
      member.reload.reactivate!(members(:f_admin))
    end
    email = ActionMailer::Base.deliveries.last
    assert member.active?
    assert_equal [member.email], email.to
    assert_equal "Your account is now reactivated!", email.subject
  end

  def test_reactivate_suspended_dormant_member
    member = members(:dormant_member)
    admin_member = members(:no_subdomain_admin)
    assert member.dormant?
    member.suspend!(admin_member, "Reason")
    assert member.suspended?

    assert_emails 1 do
      member.reactivate!(admin_member)
    end
    email = ActionMailer::Base.deliveries.last
    assert member.dormant?
    assert_equal [member.email], email.to
    assert_equal "Your account is now reactivated!", email.subject
  end

  def test_reactivate_send_email_set_false
    member = members(:dormant_member)
    admin_member = members(:no_subdomain_admin)
    assert member.dormant?
    member.suspend!(admin_member, "Reason")
    assert member.suspended?

    assert_no_emails do
      member.reactivate!(admin_member, false)
    end
    assert member.dormant?
  end

  def test_reactivate_members
    assert_no_emails do
      assert_no_difference "JobLog.count" do
        Member.reactivate_members([], members(:f_admin), JobLog.generate_uuid)
      end
    end

    assert_no_emails do
      assert_no_difference "JobLog.count" do
        Member.reactivate_members([members(:f_mentor).id], members(:f_admin), JobLog.generate_uuid)
      end
    end

    member = members(:inactive_user)
    assert_emails 1 do
      assert_difference "JobLog.count", 1 do
        Member.reactivate_members([member.id], members(:anna_univ_admin), JobLog.generate_uuid)
      end
    end
    email = ActionMailer::Base.deliveries.last
    assert member.reload.active?
    assert_equal [member.email], email.to
    assert_equal "Your account is now reactivated!", email.subject
  end

  def test_state_transition_allowed
    suspend_state = Member::Status::SUSPENDED
    active_state = Member::Status::ACTIVE
    dormant_state = Member::Status::DORMANT
    student = members(:f_student)

    # active member
    assert student.state_transition_allowed?(suspend_state)
    assert_false student.state_transition_allowed?(dormant_state)

    # suspended member
    student.state = suspend_state
    student.save
    assert student.state_transition_allowed?(active_state)
    assert_false student.state_transition_allowed?(dormant_state)

    # dormant member
    student.state = dormant_state
    student.save
    assert_false student.state_transition_allowed?(active_state)
    assert student.state_transition_allowed?(suspend_state)
  end

  def test_state_transitions_allowed
    expected_result = {
      Member::Status::ACTIVE.to_s => [Member::Status::SUSPENDED.to_s],
      Member::Status::DORMANT.to_s => [Member::Status::SUSPENDED.to_s],
      Member::Status::SUSPENDED.to_s => [Member::Status::ACTIVE.to_s]
    }
    actual_result = Member.state_transitions_allowed
    assert_equal expected_result, actual_result
  end

  def test_status_module_methods
    assert_equal_unordered [Member::Status::ACTIVE, Member::Status::DORMANT, Member::Status::SUSPENDED], Member::Status.all
    assert_equal_unordered Member::Status.all - [Member::Status::DORMANT], Member::Status.all_except(Member::Status::DORMANT)
    assert_equal_unordered Member::Status.all - [Member::Status::ACTIVE, Member::Status::DORMANT], Member::Status.all_except(Member::Status::DORMANT, Member::Status::ACTIVE)
  end

  def test_language_title
    member = members(:mentor_13)
    assert_equal "Hindi", member.language_title
    member.state = Member::Status::DORMANT
    assert_equal AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY, member.language_title
    member.member_language.destroy
    assert_equal AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY, member.language_title
    assert_equal Language.for_english.title, member.reload.language_title
    member.state = Member::Status::DORMANT
    assert_equal AdminViewColumn::LANGUAGE_NOT_SET_DISPLAY, member.language_title
  end

  def test_connected_with
    groups(:group_nwen).destroy
    groups(:group_pbe).destroy
    assert_false members(:f_mentor).connected_with?(members(:f_student))

    assert members(:f_mentor).connected_with?(members(:mkr_student))
    assert members(:mkr_student).connected_with?(members(:f_mentor))
    groups(:mygroup).terminate!(users(:f_admin), 'some reason', groups(:mygroup).program.permitted_closure_reasons.first.id)
    assert members(:mkr_student).connected_with?(members(:f_mentor))

    mod_mentor = create_user(member: members(:f_mentor_student), program: programs(:moderated_program), role_names: [RoleConstants::MENTOR_NAME])
    mod_student = create_user(member: members(:f_student), program: programs(:moderated_program), role_names: [RoleConstants::STUDENT_NAME])
    create_group(program: programs(:moderated_program), mentor: mod_mentor, students: [mod_student])
    assert mod_mentor.connected_with?(mod_student)
    members(:f_mentor_student).reload
    members(:f_student).reload
    assert members(:f_mentor_student).connected_with?(members(:f_student))
  end

  def test_name
    member = members(:f_mentor)
    assert_false member.admin?
    assert_equal 'Good unique name', member.name
    assert_equal 'Good unique name', member.name(name_only: true)

    setup_admin_custom_term
    member.promote_as_admin!
    assert member.admin?
    assert_equal 'Good unique name (Super Admin)', member.name
    assert_equal 'Good unique name', member.name(name_only: true)
  end

  def test_of_organization_scope
    assert_equal_unordered programs(:org_anna_univ).members,
        Member.of_organization(programs(:org_anna_univ))

    assert_equal_unordered programs(:org_anna_univ).members + programs(:org_foster).members,
        Member.of_organization([programs(:org_anna_univ), programs(:org_foster)])
  end

  def test_exceeded_maximum_login_attempts_scope
    member = members(:student_1)
    assert Member.exceeded_maximum_login_attempts(3).empty?
    member.update_attributes(failed_login_attempts: 4)
    assert_equal [member], Member.exceeded_maximum_login_attempts(3)
    member.update_attributes(failed_login_attempts: 2)
    assert Member.exceeded_maximum_login_attempts(3).empty?
  end

  def test_locked_out_scope
    assert Member.locked_out(3, 1.0).empty?
    members(:student_1).update_attributes(failed_login_attempts: 7, account_locked_at: Time.now.utc - 10.minute)
    assert_equal [members(:student_1)], Member.locked_out(3, 1.0)
  end

  def test_user_in_program
    assert_equal_unordered [users(:ceg_mentor), users(:psg_mentor)], members(:anna_univ_mentor).users
    assert_equal users(:psg_mentor), members(:anna_univ_mentor).user_in_program(programs(:psg))
    assert_equal users(:ceg_mentor), members(:anna_univ_mentor).user_in_program(programs(:ceg))
  end

  def test_user_roles_in_program
    assert_equal users(:psg_mentor).role_names, members(:anna_univ_mentor).user_roles_in_program(programs(:psg))
  end

  def test_inbox_unread_count
    assert_equal 4, members(:f_mentor).inbox_unread_count
    msg = create_message(sender: members(:f_admin), receiver: members(:f_mentor))
    assert_equal 5, members(:f_mentor).inbox_unread_count

    messages(:first_message).mark_as_read!(members(:f_mentor))
    assert_equal 4, members(:f_mentor).reload.inbox_unread_count

    msg.mark_deleted!(members(:f_mentor))
    assert_equal 3, members(:f_mentor).reload.inbox_unread_count
  end

  def test_should_not_destroy_message_if_member_destroyed_is_not_only_recepient
    # Destroy messages by f_mentor other than what are concerened in this test
    Scrap.destroy_all
    messages(:second_message).destroy

    message = messages(:first_message)
    assert_equal [members(:f_mentor)], message.receivers
    receiver = message.message_receivers.create(member: members(:mkr_student))
    assert ([members(:f_mentor), members(:mkr_student)] - message.reload.receivers).empty?

    assert_no_difference "Message.count" do
      assert_difference "Messages::Receiver.count", -1 do
        assert_difference "Member.count", -1 do
          members(:f_mentor).destroy
        end
      end
    end

    receiver.update_attributes!(status: AbstractMessageReceiver::Status::DELETED)
    assert_difference "Messages::Receiver.count", -1 do
      assert_difference "Member.count", -1 do
        members(:mkr_student).destroy
      end
    end
  end

  def test_received_messages_should_not_include_deleted_message
    member = members(:f_mentor)
    message = member.received_messages.first
    assert_difference "member.received_messages.count", -1 do
      message.mark_deleted!(member)
    end
  end

  def test_should_not_destroy_message_if_only_recepient_destroyed
    # Destroy messages to f_mentor other than what are concerened in this test
    Scrap.destroy_all
    messages(:second_message).destroy

    message = messages(:first_message)
    assert_equal [members(:f_mentor)], message.receivers

    assert_no_difference "Message.count" do
      assert_difference "Messages::Receiver.count", -1 do
        assert_difference "Member.count", -1 do
          members(:f_mentor).destroy
        end
      end
    end
  end

  def test_message_should_pass_validation_if_only_recepient_destroyed
    # Destroy messages to f_mentor other than what are concerened in this test
    Scrap.destroy_all
    messages(:second_message).destroy

    message = messages(:first_message)
    assert_equal [members(:f_mentor)], message.receivers

    assert_no_difference "Message.count" do
      assert_difference "Messages::Receiver.count", -1 do
        assert_difference "Member.count", -1 do
          members(:f_mentor).destroy
        end
      end
    end

    assert_equal 0, message.reload.receivers.size
    #and save call on message without any receivers should be allowed
    message.update_attributes!(subject: "No receiver for me")
    assert_equal message.subject, "No receiver for me"
  end

  def test_programs_with_permission
    assert_equal(
      [programs(:albers), programs(:pbe), programs(:moderated_program)],
      members(:f_mentor).programs_with_permission('write_article')
    )

    assert_equal(
      [programs(:nwen)],
      members(:f_mentor).programs_with_permission('send_mentor_request')
    )

    fetch_role(:nwen, :student).add_permission('write_article')
    members(:f_mentor).reload

    assert_equal(
      [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)],
      members(:f_mentor).programs_with_permission('write_article')
    )

    assert_equal(
      [programs(:albers), programs(:nwen), programs(:moderated_program), programs(:pbe)],
      members(:f_admin).programs_with_permission('manage_questions')
    )

    fetch_role(:moderated_program, :admin).remove_permission('manage_questions')
    members(:f_admin).reload
    users(:f_admin_moderated_program).reload

    assert_equal(
      [programs(:albers), programs(:nwen), programs(:pbe)],
      members(:f_admin).programs_with_permission('manage_questions')
    )
  end

  def test_common_programs_with
    assert_equal [programs(:nwen)], members(:f_mentor).common_programs_with(members(:nwen_admin))
    # Symmetry
    assert_equal [programs(:nwen)], members(:nwen_admin).common_programs_with(members(:f_mentor))

    assert_equal [programs(:albers), programs(:nwen), programs(:moderated_program), programs(:pbe)], members(:f_mentor).common_programs_with(members(:f_admin))
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe)], members(:f_mentor).common_programs_with(members(:f_student))
    assert_equal [programs(:albers), programs(:pbe)], members(:f_mentor).common_programs_with(members(:student_3))
    assert_equal [programs(:albers), programs(:pbe)], members(:student_3).common_programs_with(members(:student_3))

    assert_equal [programs(:albers), programs(:nwen), programs(:moderated_program), programs(:pbe)], members(:f_admin).active_programs

    assert_equal [programs(:psg)], members(:inactive_user).programs
    assert_equal [], members(:inactive_user).active_programs
    assert_equal [], members(:inactive_user).common_programs_with(members(:psg_only_admin))
  end

  def test_authored
    assert members(:f_mentor).authored?(articles(:kangaroo))
    assert_false members(:f_mentor).authored?(articles(:india))
    assert members(:f_admin).authored?(articles(:india))
  end

  def test_allowed_to_send_message
    groups(:group_nwen).destroy
    groups(:group_pbe).destroy
    mentor = members(:f_mentor)
    users(:f_student_nwen_mentor).role_names = [RoleConstants::STUDENT_NAME]
    users(:f_mentor_nwen_student).role_names = [RoleConstants::MENTOR_NAME]

    assert members(:f_admin).allowed_to_send_message?(mentor)
    assert members(:f_student).allowed_to_send_message?(mentor)
    assert members(:mkr_student).allowed_to_send_message?(mentor)
    assert members(:mentor_3).allowed_to_send_message?(mentor)
    assert members(:student_11).allowed_to_send_message?(mentor)

    programs(:albers).update_attribute :allow_user_to_send_message_outside_mentoring_area, false
    assert_false programs(:albers).reload.allow_user_to_send_message_outside_mentoring_area?

    assert members(:f_student).allowed_to_send_message?(mentor)
    assert members(:mkr_student).allowed_to_send_message?(mentor)
    assert members(:mentor_3).allowed_to_send_message?(mentor)
    assert members(:f_student).allowed_to_send_message?(mentor)
    assert_false members(:student_11).reload.allowed_to_send_message?(mentor)

    programs(:nwen).update_attribute :allow_user_to_send_message_outside_mentoring_area, false
    assert_false programs(:nwen).reload.allow_user_to_send_message_outside_mentoring_area?
    users(:f_student_pbe).destroy

    assert_false members(:f_student).reload.allowed_to_send_message?(mentor.reload)
    assert_false members(:student_11).reload.allowed_to_send_message?(mentor)
    assert members(:mkr_student).allowed_to_send_message?(mentor)

    #Connect FStudent to Fmentor
    create_group(mentor: users(:f_mentor), student: users(:f_student))
    assert members(:f_student).reload.allowed_to_send_message?(mentor.reload)

    # Member with only one user and in inactive state
    mentor_user = users(:psg_remove)
    mentor_user.suspend_from_program!(mentor_user, "test")
    assert members(:f_admin).allowed_to_send_message?(members(:psg_remove))
  end

  def test_has_no_users
    member = members(:f_student)
    assert_false member.has_no_users?
    ActiveRecord::Base.connection.execute("DELETE FROM users WHERE id = #{users(:f_student).id}")
    assert_false member.reload.has_no_users?
    ActiveRecord::Base.connection.execute("DELETE FROM users WHERE id = #{users(:f_student_nwen_mentor).id}")
    assert_false member.reload.has_no_users?
    ActiveRecord::Base.connection.execute("DELETE FROM users WHERE id = #{users(:f_student_pbe).id}")
    assert member.reload.has_no_users?
  end

  def test_administered_programs
   ram_program = members(:ram).programs.to_a.dup
    create_user member: members(:ram), program: programs(:nwen),
     role_names: [RoleConstants::MENTOR_NAME], first_name: "ram", last_name: "nwen_mentor"
   create_user member: members(:ram), program: programs(:moderated_program),
     role_names: [RoleConstants::STUDENT_NAME], first_name: "ram", last_name: "nwen_student"
   assert_equal members(:ram).programs.count, 3
   assert_equal members(:f_admin).programs, members(:f_admin).administered_programs
   assert_equal ram_program, members(:ram).administered_programs
  end

  def test_should_dependent_destroy_profile_picture
    member = create_member
    assert_nil member.profile_picture

    assert_difference 'ProfilePicture.count' do
      ProfilePicture.create(member: member, image: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))
    end

    assert_not_nil member.reload.profile_picture
    assert_difference("ProfilePicture.count", -1) do
      member.destroy
    end
  end

  def test_should_dependent_destroy_membership_requests
    member = members(:f_student)
    assert member.membership_requests.empty?
    assert_difference "MembershipRequest.count" do
      MembershipRequest.create!(member: member, email: member.email, program: programs(:albers), first_name: member.first_name, last_name: member.last_name, role_names: [RoleConstants::MENTOR_NAME])
    end
    assert_difference("MembershipRequest.count", -1) do
      member.destroy
    end
  end

  def test_articles_enabled_programs
    member = members(:f_mentor)
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], member.articles_enabled_programs
    programs(:albers).enable_feature(FeatureName::ARTICLES, false).reload
    assert_equal [programs(:nwen), programs(:pbe), programs(:moderated_program)], member.reload.articles_enabled_programs
    programs(:nwen).enable_feature(FeatureName::ARTICLES, false).reload
    assert_equal [programs(:pbe), programs(:moderated_program)], member.reload.articles_enabled_programs
    programs(:pbe).enable_feature(FeatureName::ARTICLES, false).reload
    assert_equal [programs(:moderated_program)], member.reload.articles_enabled_programs
    programs(:moderated_program).enable_feature(FeatureName::ARTICLES, false).reload
    assert_equal [], member.reload.articles_enabled_programs
  end

  def test_qa_enabled_programs
    member = members(:f_mentor)
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], member.qa_enabled_programs
    programs(:moderated_program).enable_feature(FeatureName::ANSWERS, false).reload
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe)], member.reload.qa_enabled_programs
    programs(:albers).enable_feature(FeatureName::ANSWERS, false).reload
    assert_equal [programs(:nwen), programs(:pbe)], member.reload.qa_enabled_programs
    programs(:nwen).enable_feature(FeatureName::ANSWERS, false).reload
    assert_equal [programs(:pbe)], member.reload.qa_enabled_programs
    programs(:pbe).enable_feature(FeatureName::ANSWERS, false).reload
    assert_equal [], member.reload.qa_enabled_programs
  end

  def test_articles_enabled
    member = members(:f_mentor)
    assert member.articles_enabled?
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], member.articles_enabled_programs
  end

  def test_articles_disabled
    member = members(:f_mentor)
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], member.articles_enabled_programs
    programs(:albers).enable_feature(FeatureName::ARTICLES, false).reload
    programs(:nwen).enable_feature(FeatureName::ARTICLES, false).reload
    programs(:pbe).enable_feature(FeatureName::ARTICLES, false).reload
    programs(:moderated_program).enable_feature(FeatureName::ARTICLES, false).reload
    assert_false member.reload.articles_enabled?
    assert_equal [], member.articles_enabled_programs
  end

  def test_qa_enabled
    member = members(:f_mentor)
    assert member.qa_enabled?
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], member.qa_enabled_programs
  end

  def test_qa_disabled
    member = members(:f_mentor)
    assert_equal [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], member.qa_enabled_programs
    programs(:moderated_program).enable_feature(FeatureName::ANSWERS, false).reload
    programs(:albers).enable_feature(FeatureName::ANSWERS, false).reload
    programs(:nwen).enable_feature(FeatureName::ANSWERS, false).reload
    programs(:pbe).enable_feature(FeatureName::ANSWERS, false).reload
    assert_false member.reload.qa_enabled?
    assert_equal [], member.qa_enabled_programs
  end

  def test_article_manageable_programs
    member = members(:f_mentor)
    assert_equal [], member.article_manageable_programs

    users(:f_mentor).add_role(RoleConstants::ADMIN_NAME)
    assert_equal [programs(:albers)], member.reload.article_manageable_programs

    users(:f_mentor_nwen_student).add_role(RoleConstants::ADMIN_NAME)
    assert_equal [programs(:albers), programs(:nwen)], member.reload.article_manageable_programs
  end

  def test_mark_attending
    assert members(:f_mentor).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    member_meetings(:member_meetings_1).update_attribute(:attending, false)
    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student), attending: false)
    assert_false members(:f_mentor).is_attending?(meetings(:f_mentor_mkr_student).reload, meetings(:f_mentor_mkr_student).start_time)
    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student), attending: true)
    assert members(:f_mentor).reload.is_attending?(meetings(:f_mentor_mkr_student).reload, meetings(:f_mentor_mkr_student).start_time)
  end

  def test_is_attending
    assert members(:f_mentor).is_attending?(meetings(:f_mentor_mkr_student), meetings(:f_mentor_mkr_student).start_time)
    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student), attending: false)
    assert_false members(:f_mentor).is_attending?(meetings(:f_mentor_mkr_student).reload, meetings(:f_mentor_mkr_student).start_time)
  end

  def test_owner_in_organization
    members(:ram).promote_as_admin!
    programs(:albers).owner = users(:ram)
    programs(:albers).save
    members(:robert).promote_as_admin!
    members(:ram).organization.reload
    assert_false members(:ram).no_owner_in_organization?
    assert members(:robert).no_owner_in_organization?
  end

  def test_can_be_removed_or_suspended
    member = members(:f_mentor)
    assert member.can_be_removed_or_suspended?

    member.stubs(:no_owner_in_organization?).returns(false)
    assert_false member.can_be_removed_or_suspended?

    member.stubs(:is_chronus_admin?).returns(true)
    assert_false member.can_be_removed_or_suspended?

    member.stubs(:no_owner_in_organization?).returns(true)
    assert_false member.can_be_removed_or_suspended?
  end

  def test_can_remove_or_suspend
    admin = members(:f_admin)
    member = members(:f_mentor)
    assert admin.can_remove_or_suspend?(member)
    assert_false admin.can_remove_or_suspend?(admin)
    assert_false member.can_remove_or_suspend?(member)
    assert_false member.can_remove_or_suspend?(admin)

    member.stubs(:can_be_removed_or_suspended?).returns(false)
    assert_false admin.can_remove_or_suspend?(member)
  end

  def test_removal_or_suspension_scope
    organization = programs(:org_primary)
    member_1 = members(:f_mentor)
    member_2 = members(:f_student)
    member_3 = members(:f_mentor_student)
    members = [member_1, member_2, member_3]
    members_scope = organization.members.where(id: members.collect(&:id))
    assert_equal_unordered members, Member.removal_or_suspension_scope(members_scope, organization, members(:f_admin).id).to_a

    user_1 = member_1.users.first
    user_1.program.update_attribute(:user_id, user_1.id)
    assert_equal [member_2], Member.removal_or_suspension_scope(members_scope, organization, member_3.id).to_a

    member_2.admin = true
    member_2.save!
    assert_equal [member_2], Member.removal_or_suspension_scope(members_scope, organization, member_3.id).to_a

    member_2.email = SUPERADMIN_EMAIL
    member_2.save!
    assert_equal [member_3], Member.removal_or_suspension_scope(members_scope, organization, 0).to_a
  end

  def test_get_mentoring_slots
    t1 = "2011-02-20 00:00:00".to_time
    t2 = "2011-02-27 00:00:00".to_time
    t3 = "2011-03-06 00:00:00".to_time
    members(:f_mentor).update_attribute(:time_zone, "Asia/Kolkata")

    m= {title: "#{members(:f_mentor).reload.name} available at -",allDay: false, repeats: 2, dbId: 1, eventMemberId: members(:f_mentor).id, clickable: false,
      location: "-", new_meeting_params: {mentor_id: members(:f_mentor).id, location: "-"}, editable: false}

    date_t1 = t1.to_date
    date_t2 = t2.to_date
    date_t3 = t3.to_date
    slots_hash_with_recurring_options = {title: "#{members(:f_mentor).reload.name} available at Not specified", allDay: false, repeats: 2, dbId: 1, eventMemberId: 3, location: "Not specified", new_meeting_params: {location: "Not specified", mentor_id: 3}, editable: false, recurring_options: {starts: date_t2, until: date_t3, recurring_slot_end_time: "", every: :week, on: [:saturday]}, start: "2011-03-05T08:30:00Z", end: "2011-03-06T00:00:00Z", clickable: false}

    # Ending at midnight
    mentoring_slots(:f_mentor).update_attributes(start_time: "2011-02-26 08:30:00", end_time: "2011-02-27 00:00:00", repeats: 2,
      repeats_on_week: "2011-02-26 08:30:00".to_date.wday)
    assert_equal members(:f_mentor).reload.get_mentoring_slots(t1, t2),
      [m.merge({start: "2011-02-26T08:30:00Z", end: "2011-02-27T00:00:00Z"})]

    assert_equal members(:f_mentor).get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T08:30:00Z", end: "2011-03-06T00:00:00Z"})]

    assert_equal [slots_hash_with_recurring_options], members(:f_mentor).get_mentoring_slots(t2, t3, false, nil, false, false, false, false, {mentor_settings_page: true})

    mentoring_slots(:f_mentor).update_attributes(start_time: "2011-02-26 08:30:00", end_time: "2011-02-26 10:30:00", repeats: 2)
    assert_equal members(:f_mentor).reload.get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T08:30:00Z", end: "2011-03-05T10:30:00Z"})]

    assert_equal members(:f_mentor).get_mentoring_slots(t1, t2),
      [m.merge({start: "2011-02-26T08:30:00Z", end: "2011-02-26T10:30:00Z"})]
    assert_equal members(:f_mentor).get_mentoring_slots("2011-02-13 00:00:00".to_time, t1),
      []

    # Starting at midnight
    mentoring_slots(:f_mentor).update_attributes(start_time: "2011-02-26 00:00:00", end_time: "2011-02-26 10:00:00", repeats: 2,
      repeats_on_week: "2011-02-26 08:30:00".to_date.wday)
    assert_equal members(:f_mentor).reload.get_mentoring_slots(t1, t2),
      [m.merge({start: "2011-02-26T00:00:00Z", end: "2011-02-26T10:00:00Z"})]

    assert_equal members(:f_mentor).get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T00:00:00Z", end: "2011-03-05T10:00:00Z"})]

    mentoring_slots(:f_mentor).update_attribute(:repeats_end_date, "2011-03-10")
    assert_equal members(:f_mentor).reload.get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T00:00:00Z", end: "2011-03-05T10:00:00Z"})]

    mentoring_slots(:f_mentor).update_attribute(:repeats_end_date, "2011-03-07")
    assert_equal members(:f_mentor).reload.get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T00:00:00Z", end: "2011-03-05T10:00:00Z"})]

    mentoring_slots(:f_mentor).update_attribute(:repeats_end_date, "2011-03-06")
      assert_equal members(:f_mentor).reload.get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T00:00:00Z", end: "2011-03-05T10:00:00Z"})]

    mentoring_slots(:f_mentor).update_attribute(:repeats_end_date, "2011-03-07")
    assert_equal members(:f_mentor).reload.get_mentoring_slots(t2, t3),
      [m.merge({start: "2011-03-05T00:00:00Z", end: "2011-03-05T10:00:00Z"})]

    mentoring_slots(:f_mentor).update_attribute(:repeats, MentoringSlot::Repeats::MONTHLY)
    mentoring_slots(:f_mentor).update_attribute(:repeats_end_date, "2011-03-27")
    assert_equal [m.merge({start: "2011-02-26T00:00:00Z", end: "2011-02-26T10:00:00Z",
        repeats: MentoringSlot::Repeats::MONTHLY})],
      members(:f_mentor).reload.get_mentoring_slots("2011-02-26 00:00:00".to_time, "2011-03-05 00:00:00".to_time)

    assert_equal [], members(:f_mentor).reload.get_mentoring_slots("2011-03-03 00:00:00".to_time, "2011-03-10 00:00:00".to_time)
    assert_equal [], members(:f_mentor).reload.get_mentoring_slots("2011-03-03 00:00:00".to_time, "2011-03-10 00:00:00".to_time)
    assert_equal [m.merge({start: "2011-03-26T00:00:00Z", end: "2011-03-26T10:00:00Z",
      repeats: MentoringSlot::Repeats::MONTHLY})],
      members(:f_mentor).reload.get_mentoring_slots("2011-03-26 00:00:00".to_time, "2011-04-02 00:00:00".to_time)

    mentoring_slots(:f_mentor).update_attributes(start_time: "2011-03-26 08:30:00", end_time: "2011-03-27 00:00:00",
      repeats: MentoringSlot::Repeats::MONTHLY, repeats_by_month_date: false, repeats_end_date: "2011-04-24")
    assert_false mentoring_slots(:f_mentor).reload.repeats_by_month_date?

    assert_equal [m.merge({start: "2011-04-23T08:30:00Z", end: "2011-04-24T00:00:00Z",
      repeats: MentoringSlot::Repeats::MONTHLY})],
      members(:f_mentor).reload.get_mentoring_slots("2011-04-16 00:00:00".to_time, "2011-04-23 00:00:00".to_time)

    assert_equal  "Asia/Kolkata", members(:f_mentor).get_valid_time_zone
    members(:f_mentor).update_attribute(:time_zone, "")
    assert_not_equal "Asia/Kolkata", members(:f_mentor).get_valid_time_zone
    assert_equal  TimezoneConstants::DEFAULT_TIMEZONE, members(:f_mentor).get_valid_time_zone
  end

  def test_weekly_slots_with_different_timezones
    t1 = "2011-02-20 00:00:00".to_time
    t2 = "2011-02-27 00:00:00".to_time

    mentoring_slots(:f_mentor).update_attributes(start_time: "2011-02-26 01:00:00", end_time: "2011-02-26 01:30:00", repeats: 2,
      repeats_on_week: "2011-02-26 08:30:00".to_date.wday)
    Time.stubs(:zone).returns(ActiveSupport::TimeZone.new("Etc/GMT+12"))
    result = members(:f_mentor).reload.get_mentoring_slots(t1, t2, false, nil, true)
    expected_result = {start: "2011-02-25T13:00:00Z", end: "2011-02-25T13:30:00Z"}
    assert_equal expected_result, result[0].pick(:start, :end)
  end

  def test_not_having_any_meeting_during_interval
    member = members(:f_mentor)
    meeting = meetings(:f_mentor_mkr_student)

    current_time = Time.now
    meeting_start_time = current_time + 2.hours
    meeting_end_time = meeting_start_time + 30.minutes

    meeting.update_attributes(start_time: meeting_start_time, end_time: meeting_end_time)

    Member.any_instance.stubs(:get_attending_or_unanswred_recurrent_meetings_within_time).returns([{current_occurrence_time: current_time + 2.hours, meeting: meeting}])

    assert member.not_having_any_meeting_during_interval?(meeting_start_time - 1.hour, meeting_start_time)
    assert member.not_having_any_meeting_during_interval?(meeting_start_time - 1.hour, meeting_start_time - 1.minute)

    assert member.not_having_any_meeting_during_interval?(meeting_end_time , meeting_end_time + 4.hours)
    assert member.not_having_any_meeting_during_interval?(meeting_end_time + 1.minute, meeting_end_time + 1.hour)

    assert_false member.not_having_any_meeting_during_interval?(meeting_start_time + 10.minutes, meeting_start_time + 20.minutes)
    assert_false member.not_having_any_meeting_during_interval?(meeting_start_time - 10.minutes, meeting_start_time + 20.minutes)
    assert_false member.not_having_any_meeting_during_interval?(meeting_end_time - 10.minutes, meeting_end_time + 20.minutes)

    Member.any_instance.stubs(:get_attending_or_unanswred_recurrent_meetings_within_time).returns([])

    assert member.not_having_any_meeting_during_interval?(current_time + 2.hours + 10.minutes, current_time + 2.hours + 40.minutes)
  end

  def test_get_mentoring_slots_for_mentor
    member = members(:f_mentor)
    slot_start_time = "2100-02-20 07:00:00".to_time
    slot_end_time = "2100-02-20 08:00:00".to_time
    repeats_end_date = "2100-03-26".to_date
    #repeats daily
    slot1 = create_mentoring_slot(member: member, location: "Bangalore",
      start_time: slot_start_time, end_time: slot_end_time,
      repeats: MentoringSlot::Repeats::DAILY, repeats_on_week: nil)
    slot1.save
    start_time = slot_start_time - 30.minutes
    end_time = start_time + 30.days
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 1, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: "", every: :week, on: [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]}, start: "2100-02-20T01:30:00Z", end: "2100-02-20T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})

    #repeats_daily_with_end_time
    slot1.update_attributes(repeats_end_date: repeats_end_date)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 1, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: slot1.repeats_end_date - 1.day, every: :week, on: [:sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday]}, start: "2100-02-20T01:30:00Z", end: "2100-02-20T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})

    #repeats weekly
    slot1.update_attributes(repeats_on_week: "0,1,2", repeats: 2, repeats_end_date: nil)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 2, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: "", every: :week, on: [:sunday, :monday, :tuesday]}, start: "2100-02-21T01:30:00Z", end: "2100-02-21T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})

    #repeats weekly_with_end_time
    slot1.update_attributes(repeats_end_date: repeats_end_date)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 2, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: slot1.repeats_end_date - 1.day, every: :week, on: [:sunday, :monday, :tuesday]}, start: "2100-02-21T01:30:00Z", end: "2100-02-21T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})

    #repeats monthly
    #by_date
    slot1.update_attributes(repeats_by_month_date: true, repeats: 3, repeats_end_date: nil)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 3, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: "", every: :month, on: 20}, start: "2100-02-20T01:30:00Z", end: "2100-02-20T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})
    #by_day
    slot1.update_attributes(repeats_by_month_date: false, repeats: 3)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 3, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: "", every: :month, weekday: :saturday, on: :third}, start: "2100-02-20T01:30:00Z", end: "2100-02-20T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})


    #repeats monthly with end_time
    #by_date
    slot1.update_attributes(repeats_end_date: repeats_end_date, repeats_by_month_date: true)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 3, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: slot1.repeats_end_date - 1.day, every: :month, on: 20}, start: "2100-02-20T01:30:00Z", end: "2100-02-20T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})
    #by_day
    slot1.update_attributes(repeats_by_month_date: false, repeats: 3)
    member.mentoring_slots.reload
    slot_hash = {title: "Good unique name available at Bangalore", allDay: false, repeats: 3, dbId: slot1.id, eventMemberId: 3, location: "Bangalore", new_meeting_params: {location: "Bangalore", mentor_id: 3}, editable: false, recurring_options: {starts: start_time.to_date, until: end_time.to_date, recurring_slot_end_time: slot1.repeats_end_date - 1.day, every: :month, weekday: :saturday, on: :third}, start: "2100-02-20T01:30:00Z", end: "2100-02-20T02:30:00Z", clickable: false}
    assert_equal [slot_hash], member.get_mentoring_slots(start_time, end_time, false, nil, false, false, false, false, {mentor_settings_page: true})
  end

  def test_get_member_availability_after_meetings
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    t1 = "2025-02-20 00:00:00".to_datetime
    t2 = "2025-02-27 00:00:00".to_datetime
    m = {title: "#{members(:f_mentor).name} available at -",allDay: false, repeats: 2, dbId: mentoring_slots(:f_mentor).id, eventMemberId: members(:f_mentor).id, clickable: false, location: "-", new_meeting_params: {mentor_id: members(:f_mentor).id, location: "-"}, editable: false}
     mentoring_slots(:f_mentor).update_attributes(start_time: "2025-02-26 12:00:00", end_time: "2025-02-26 19:00:00", repeats: 2, repeats_on_week: "2025-02-26 12:00:00".to_date.wday)

    meet = meetings(:f_mentor_mkr_student)
    program = meet.program

    update_recurring_meeting_start_end_date(meet, "2025-02-26 14:00:00".to_datetime, "2025-02-26 15:00:00".to_datetime, {duration: 1.hour})
    men_slots = members(:f_mentor).reload.get_mentoring_slots(t1, t2)
    assert_equal_unordered members(:f_mentor).get_member_availability_after_meetings(men_slots,t1, t2, program),
      [m.merge({start: "2025-02-26T12:00:00Z", end: "2025-02-26T14:00:00Z"}), m.merge({start: "2025-02-26T15:00:00Z", end: "2025-02-26T19:00:00Z"})]

    update_recurring_meeting_start_end_date(meet, "2025-02-26 14:00:00".to_datetime, "2025-02-26 21:00:00".to_datetime, {duration: 7.hour})
    men_slots = members(:f_mentor).reload.get_mentoring_slots(t1, t2)
    assert_equal members(:f_mentor).get_member_availability_after_meetings(men_slots,t1, t2, program),
      [m.merge({start: "2025-02-26T12:00:00Z", end: "2025-02-26T14:00:00Z"})]

    update_recurring_meeting_start_end_date(meet, "2025-02-26 10:00:00".to_datetime, "2025-02-26 21:00:00".to_datetime, {duration: 11.hour})
    men_slots = members(:f_mentor).reload.get_mentoring_slots(t1, t2)
    assert members(:f_mentor).get_member_availability_after_meetings(men_slots,t1, t2, program).empty?

    update_recurring_meeting_start_end_date(meet, "2025-02-26 12:00:00".to_datetime, "2025-02-26 14:00:00".to_datetime, {duration: 2.hour})
    men_slots = members(:f_mentor).reload.get_mentoring_slots(t1, t2)
    assert_equal members(:f_mentor).get_member_availability_after_meetings(men_slots,t1, t2, program), [m.merge({start: "2025-02-26T14:00:00Z", end: "2025-02-26T19:00:00Z"})]

    update_recurring_meeting_start_end_date(meet, "2025-02-26 18:00:00".to_datetime, "2025-02-26 19:00:00".to_datetime, {duration: 1.hour})
    men_slots = members(:f_mentor).reload.get_mentoring_slots(t1, t2)
    assert_equal members(:f_mentor).get_member_availability_after_meetings(men_slots,t1, t2, program), [m.merge({start: "2025-02-26T12:00:00Z", end: "2025-02-26T18:00:00Z"})]

    members(:f_mentor).mark_attending!(meetings(:f_mentor_mkr_student), attending: false)
    meetings(:f_mentor_mkr_student).reload
    men_slots = members(:f_mentor).reload.get_mentoring_slots(t1, t2)
    assert_equal men_slots, members(:f_mentor).get_member_availability_after_meetings(men_slots,t1, t2, program)
  end

  def test_get_availability_slots
    users(:f_mentor).user_setting.update_attributes(max_meeting_slots: 2)
    users(:f_mentor).reload

    user = users(:f_mentor)
    member = user.member
    program = user.program
    student = users(:mkr_student)
    time_now = Time.now.utc.change(usec: 0)

    Time.stubs(:now).returns(time_now.beginning_of_month + 4.days)
    mentoring_slots(:f_mentor).update_attributes!(start_time: Time.now + 1.hour, end_time: Time.now + 1.hour + 30.minutes)
    st = mentoring_slots(:f_mentor).start_time.utc

    Time.stubs(:local).returns(Time.now)
    start_time = st-2.days
    end_time = st+2.days

    daily_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    start_time = st  - (2.days + 5.hours + 30.minutes)
    end_time = st + 3.days + 5.hours
    update_recurring_meeting_start_end_date(daily_meeting, start_time, end_time)

    assert_equal 2, user.user_setting.max_meeting_slots
    availability = member.get_availability_slots(start_time, end_time, user.program, true, nil, false, student)
    assert_equal [], availability

    daily_meeting.update_attribute(:active, false)
    invalidate_albers_calendar_meetings

    availability = member.get_availability_slots(start_time, end_time, user.program, true, nil, false, student)
    assert_equal member.get_member_availability_after_meetings(member.get_mentoring_slots(start_time, end_time, true),
            start_time, end_time, program), availability
    #if max meeting slots for the mentor is set as 2, after one meeting, no more availability should be shown
    update_recurring_meeting_start_end_date(meetings(:f_mentor_mkr_student), (st - 100.minutes), (st - 20.minutes), {duration: 80.minutes})
    assert_equal 2, user.user_setting.max_meeting_slots

    create_meeting(owner_id: members(:f_mentor).id, members: [members(:f_mentor), members(:mkr_student)], force_non_time_meeting: true, force_non_group_meeting: true, start_time: start_time, end_time: start_time + 30.minutes)

    availability = member.get_availability_slots(start_time, end_time, user.program, true, nil, false, student)
    assert_equal [], availability

    #for mentoring slots on the first day of the month
    last_day = "31 Dec, 2020".to_datetime
    first_day = last_day+1.day
    st = last_day+2.hours
    et = last_day+4.hours
    mentoring_slots(:f_mentor).update_attributes!(start_time: st, end_time: et)
    member.reload
    assert_blank member.get_availability_slots(first_day.beginning_of_day, first_day.end_of_day, user.program, true, nil, false, student)
    availability = member.get_availability_slots(last_day.beginning_of_day, last_day.end_of_day, user.program, true, nil, false, student)
    assert_equal st, availability.first[:start].to_datetime
    assert_equal et, availability.first[:end].to_datetime
    assert_equal 1, availability.size
  end

  def test_get_availability_slots_no_duplicate_for_multiple_months
    invalidate_albers_calendar_meetings
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    users(:f_mentor).user_setting.update_attributes(max_meeting_slots: 2)
    users(:f_mentor).reload
    user = users(:f_mentor)
    member = user.member
    program = user.program
    student = users(:mkr_student)
    st = mentoring_slots(:f_mentor).start_time
    start_time = st.beginning_of_month
    end_time = start_time + 3.months

    availability = member.get_availability_slots(start_time, end_time, program, true, nil, false, student)
    assert_equal 1, availability.size
    assert_equal st, availability.first[:start].to_datetime
  end

  def test_clickable_mentoring_slots
    mentor = members(:mentor_0)
    create_mentoring_slot(member: mentor, location: "Bangalore",
                          start_time: 25.hours.from_now, end_time: 27.hours.from_now,
                          repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)
    slot = mentor.reload.get_mentoring_slots(23.hours.from_now,48.hours.from_now, true)
    assert slot[0][:clickable]
    assert_false slot[0][:editable]

    create_mentoring_slot(member: mentor, location: "Chennai",
                          start_time: 2.hours.from_now, end_time: 7.hours.from_now,
                          repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)
    slot = mentor.reload.get_mentoring_slots(1.hour.from_now, 1.day.from_now, true)
    assert slot[0][:clickable]
    assert_false slot[0][:editable]
  end

  def test_get_meeting_slots
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    invalidate_albers_calendar_meetings
    m = members(:f_mentor).meetings.first
    update_recurring_meeting_start_end_date(m, "2011-02-26 12:00:00".to_datetime, "2011-02-27 19:00:00".to_datetime, {duration: 7.hours})
    update_duration(m, 7.hours)
    m1 = [{title: "Arbit Topic", start: "2011-02-26T12:00:00Z", end: "2011-02-26T19:00:00Z", allDay: false, dbId: m.id, show_meeting_url: "/p/albers/meetings/1?current_occurrence_time=2011-02-26+12%3A00%3A00+UTC&outside_group=true", eventMemberId: members(:f_mentor).id, className: "meetings", clickable: true, editable: false, :onclick_message=>nil}, {title: "Arbit Topic", start: "2011-02-27T12:00:00Z", end: "2011-02-27T19:00:00Z", allDay: false, dbId: m.id, show_meeting_url: "/p/albers/meetings/1?current_occurrence_time=2011-02-27+12%3A00%3A00+UTC&outside_group=true", eventMemberId: members(:f_mentor).id, className: "meetings", clickable: true, editable: false, :onclick_message=>nil}]
    assert_equal m1, members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor))
    assert_equal ["#{members(:f_mentor).name} has marked this time as busy and will not be available", "#{members(:f_mentor).name} has marked this time as busy and will not be available"], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), [], members(:f_mentor)).map{|slot| slot[:onclick_message]}

    Meeting.any_instance.stubs(:accepted?).returns(false)
    Meeting.any_instance.stubs(:archived?).returns(true)
    assert_equal ["This slot is blocked because you have a pending request at this time.", "This slot is blocked because you have a pending request at this time."], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:mkr_student)).map{|slot| slot[:onclick_message]}
    assert_equal ["This slot is blocked because you have a pending request at this time.", "This slot is blocked because you have a pending request at this time."], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor)).map{|slot| slot[:onclick_message]}
    assert_equal [true, true], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor)).map{|slot| slot[:clickable]}

    assert_equal ["requested_meetings", "requested_meetings"], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor)).map{|slot| slot[:className]}

    assert_equal [false, false], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), [], members(:f_mentor)).map{|slot| slot[:clickable]}

    Meeting.any_instance.stubs(:archived?).returns(false)
    assert_equal [true, true], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), [], members(:f_mentor)).map{|slot| slot[:clickable]}

    assert_equal ["non_self_meetings", "non_self_meetings"], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), [], members(:f_mentor)).map{|slot| slot[:className]}

    Meeting.any_instance.stubs(:accepted?).returns(true)

    assert_equal ["Busy - #{members(:f_mentor).name}", "Busy - #{members(:f_mentor).name}"], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), [], members(:f_mentor)).map{|m| m[:title]}

    m.member_meetings.where(member_id: members(:f_mentor).id).first.update_attribute(:attending, MemberMeeting::ATTENDING::NO)

    assert_equal [], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), [], members(:f_mentor))

    members(:f_mentor).mark_attending_for_an_occurrence!(m, attending = MemberMeeting::ATTENDING::YES, "2011-02-27T12:00:00Z")

    assert_equal [m1[1]], members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor))

    assert members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings.non_group_meetings, {get_merged_list: true}), members(:f_mentor).meetings.pluck(:id), members(:f_mentor)).blank?
    assert members(:f_mentor).get_meeting_slots(Meeting.recurrent_meetings(members(:f_mentor).reload.meetings.non_group_meetings, {get_merged_list: true}), [], members(:f_mentor)).blank?
  end

  def test_api_creation_deletion
    ad = members(:f_admin)
    assert_false ad.api_is_enabled?
    assert ad.enable_api!
    assert_not_equal ad.reload.api_key, ""
    assert ad.api_is_enabled?
    assert ad.disable_api!
    assert_false ad.api_is_enabled?
  end

  def test_get_locations
    members(:f_mentor).mentoring_slots.first.update_attribute(:location, "Bhopal")
    men = create_mentoring_slot(member: members(:f_mentor), location: "Indore")
    assert_equal members(:f_mentor).mentoring_slots.last, men
    men1 = create_mentoring_slot(member: members(:f_mentor), location: "")
    assert_equal members(:f_mentor).mentoring_slots.last, men1
    men2 = create_mentoring_slot(member: members(:f_mentor))
    assert_equal members(:f_mentor).mentoring_slots.last, men2
    assert_equal members(:f_mentor).get_locations, ["Bhopal", "Indore", "Chennai"]
  end

  def test_error_message_with_auth_config_password_message
    member = members(:mentor_1)
    chronus_auth = member.organization.chronus_auth
    chronus_auth.password_message = "Only show this message in the flash"
    chronus_auth.regex_string = "^.*(?=.{15,})(?=.*\\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[\@\#\$\%\^\&\+\=\!]).*$"
    chronus_auth.save!

    member.password = "manju"
    member.password_confirmation = "man"
    member.save
    assert_equal member.errors.messages[:password], ["is invalid"]

    member.password = "manju123@Mmanju123@Mmanju123@M"
    member.password_confirmation = "manju123"
    member.save
    assert_equal ["doesn't match confirmation"], member.errors.messages[:password_confirmation]
  end

  def test_program_with_given_regex
    chronus_auth = programs(:org_primary).chronus_auth
    chronus_auth.regex_string = "(?=.{8,})(?=.*\\d)(?=.*[a-z])(?=.*[A-Z])(?=(.*[~!@\#$%^&*-+=`.,?/:;_|(){}<>\\[\\]]){2,})"
    chronus_auth.password_message = "should be at least 8 characters long and have 1 upper case, 1 lower case, 1 numeric and 2 special characters"
    chronus_auth.save!

    # No of special characters is not 2
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :password do
      create_member(password: "xyXYz11=", password_confirmation: "xyXYz11=")
    end

    # No Numeric
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :password do
      create_member(password: "xyXYz+~=", password_confirmation: "xyXYz+~=")
    end

    # No Upper case
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :password do
      create_member(password: "xysda1+=", password_confirmation: "xysda1+=")
    end

    # No Lower case
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :password do
      create_member(password: "SDDXY1+=", password_confirmation: "SDDXY1+=")
    end

    assert_nothing_raised do
      assert_difference "Member.count" do
        create_member(password: "xyXYz1~=", password_confirmation: "xyXYz1~=")
      end
    end
  end

  def test_non_numeric_characters_validation
    message = "contains numeric characters"
    #Existing members
    m1 = members(:f_admin)

    m1.first_name = "sample1"
    assert_multiple_errors([{field: :first_name, message: message}]) do
      m1.save!
    end

    m1.last_name = "sa234mple"
    assert_multiple_errors([{field: :first_name, message: message}, {field: :last_name, message: message}]) do
      m1.save!
    end

    m1.first_name = "sample"
    assert_multiple_errors([{field: :last_name, message: message}]) do
      m1.save!
    end

    m1.last_name = "manju"
    assert m1.save!

    #New Member
    assert_multiple_errors([{field: :first_name, message: message}]) do
      create_member(first_name: "S2ample")
    end

    assert_multiple_errors([{field: :first_name, message: message}, {field: :last_name, message: message}]) do
      create_member(first_name: "S2ample", last_name: "234")
    end

    assert_multiple_errors([{field: :last_name, message: message}]) do
      create_member(last_name: "234")
    end

    new_member = create_member
    assert_equal "first_name", new_member.first_name
    assert_equal "some_name", new_member.last_name
  end

  def test_has_many_educations
    member = members(:ram)
    member.educations.each{|e| e.destroy}
    question = profile_questions(:multi_education_q)
    assert member.educations.empty?
    edu_1 = create_education(member, question, graduation_year: 2005)
    edu_2 = create_education(member, question, graduation_year: 2007)
    edu_3 = create_education(member, question, graduation_year: 2003)
    assert_equal [edu_2, edu_1, edu_3], member.reload.educations
  end

  def test_has_many_experiences
    member = members(:ram)
    member.experiences.each{|e| e.destroy}
    question = profile_questions(:multi_experience_q)
    assert member.experiences.empty?
    exp_1 = create_experience(member, question, start_year: 1970, end_year: nil) # Leaving :end_year as nil
    exp_2 = create_experience(member, question, start_year: 1978, end_year: 1980)
    exp_3 = create_experience(member, question, start_year: 1980, end_year: 1990, end_month: 1)
    exp_4 = create_experience(member, question, start_year: 1969, end_year: nil) # Leaving :end_year as nil
    exp_5 = create_experience(member, question, start_year: 1990, end_year: nil, current_job: true) # current job
    exp_6 = create_experience(member, question, start_year: 1980, end_year: 1990)
    exp_7 = create_experience(member, question, start_year: 1995, end_year: nil, current_job: true) # current job
    exp_8 = create_experience(member, question, start_year: 1980, end_year: 1990, end_month: 3)
    exp_9 = create_experience(member, question, start_year: 1980, end_year: 1990, end_month: 7)

    # Sort order:
    # 1 - end_year having 'Present'
    # 2 - end_year not null and in reverse chronological order
    # 3 - end_year is null
    # Note: Records are sorted based on the 'id' within each set. We do not respect the start_year
    assert_equal_unordered [exp_5, exp_7, exp_9, exp_8, exp_3, exp_6, exp_2, exp_1, exp_4], member.reload.experiences
  end

  def test_increment_login_counter
    member = members(:ram)
    assert_equal 0, member.failed_login_attempts
    member.increment_login_counter!
    member.reload
    assert_equal 0, member.failed_login_attempts
    #Enable the login attempts feature
    programs(:org_primary).security_setting.update_attributes!(maximum_login_attempts: 2)
    member.increment_login_counter!
    member.reload
    assert_equal 1, member.failed_login_attempts
    member.increment_login_counter!
    member.reload
    assert_equal 2, member.failed_login_attempts
  end

  def test_full_time_zone
    member = members(:ram)
    member.time_zone = "Asia/Hong_Kong"
    member.save!
    assert_equal "(GMT+08:00) Asia/Hong Kong", member.full_time_zone

    member.time_zone = nil
    member.save!
    assert_equal "(GMT+00:00) Etc/UTC", member.full_time_zone
  end

  def test_login_attempts_exceeded
    member = members(:ram)
    org = member.organization
    org.security_setting.update_attributes!(maximum_login_attempts: 2)
    assert_false member.login_attempts_exceeded?
    member.increment_login_counter!
    assert_false member.login_attempts_exceeded?
    member.increment_login_counter!
    assert_false member.login_attempts_exceeded?
    member.increment_login_counter!
    assert member.login_attempts_exceeded?
  end

  def test_reset_login_counter
    member = members(:ram)
    org = member.organization
    org.security_setting.update_attributes!(maximum_login_attempts: 2)
    member.increment_login_counter!
    assert_equal 1, member.failed_login_attempts
    member.reset_login_counter!
    assert_equal 0, member.failed_login_attempts
  end

  def test_send_reactivation_email
    member = members(:ram)
    assert_emails 1 do
      member.send_reactivation_email
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal 1, email.to.size
    assert_equal member.email, email.to.first
    assert_equal "Reactivate Your Account", email.subject

    assert_emails 1 do
      member.send_reactivation_email(false)
    end
    email = ActionMailer::Base.deliveries.last
    assert_equal 1, email.to.size
    assert_equal member.email, email.to.first
    assert_equal "It's time to reset your password", email.subject
  end

  def test_account_lockout
    member = members(:ram)
    assert_nil member.account_locked_at
    member.account_lockout!
    assert member.account_locked_at.present?
    current_locked_time = member.account_locked_at
    time_traveller(1.second.from_now) do
      member.account_lockout!
      assert_not_equal current_locked_time, member.account_locked_at
    end
  end

  def test_handle_reactivate_account!
    member = members(:ram)
    assert_nil member.account_locked_at
    assert_equal member.failed_login_attempts, 0
    setting = member.organization.security_setting

    setting.maximum_login_attempts = Organization::DISABLE_MAXIMUM_LOGIN_ATTEMPTS + 3
    member.account_lockout!(true)
    member.handle_reactivate_account!(true)
    assert_nil member.account_locked_at
    assert_equal member.failed_login_attempts, 0

    setting.maximum_login_attempts = Organization::DISABLE_MAXIMUM_LOGIN_ATTEMPTS
    member.account_lockout!(true)
    member.handle_reactivate_account!(true)
    assert_nil member.account_locked_at
    assert_equal member.failed_login_attempts, 0
  end

  def test_can_reactivate_account_in_disabled_org
    member = members(:ram)
    assert member.can_reactivate_account?
    member.account_lockout!
    assert member.can_reactivate_account?
    member.update_attributes!(account_locked_at: Time.now - 2.days)
    assert member.can_reactivate_account?
  end

  def test_can_reactivate_account_in_enabled_org
    member = members(:ram)
    org = member.organization
    org.security_setting.update_attributes!({maximum_login_attempts: 1, auto_reactivate_account: Organization::DISABLE_AUTO_REACTIVATE_PASSWORD})
    assert member.can_reactivate_account?
    member.account_lockout!
    assert_false member.can_reactivate_account?
    member.update_attributes!(account_locked_at: Time.now - 2.days)
    assert_false member.can_reactivate_account?
    member.reactivate_account!
    assert member.can_reactivate_account?
  end

  def test_reactivate_account
    member = members(:ram)
    org = member.organization
    org.security_setting.update_attributes!(maximum_login_attempts: 1)
    member.increment_login_counter!
    member.increment_login_counter!
    assert_equal 2, member.failed_login_attempts
    member.last_name = ""
    member.reactivate_account!(false)
    assert_raise(ActiveRecord::RecordInvalid) do
      member.reactivate_account!
    end
    member.last_name = "raman"
    member.reactivate_account!
    assert_nil member.account_locked_at
    assert_equal 0, member.reload.failed_login_attempts
  end

  def test_imported_at_date_after_create_dormant_user
    Timecop.freeze do
      member = create_member(state: Member::Status::DORMANT, imported_at: Time.current)
      assert_equal Time.current.change(usec: 0), member.imported_at
      member2 = create_member(email: 'some@chronus.com')
      assert_nil member2.imported_at
    end
  end

  def test_created_at_time_for_dormant_user_entering_into_system
    member = create_member(state: Member::Status::DORMANT, imported_at: Time.new(1990))
    intial = member.created_at
    imported = member.imported_at
    assert member.dormant?
    Timecop.freeze(Time.now + 5.days) do
      member.users.create!(program: programs(:albers), roles: [programs(:albers).roles.first])
      member.reload
      assert_equal Time.now.to_i, member.created_at.to_i
      assert_not_equal intial, member.created_at
      assert_equal imported.to_date, member.imported_at.to_date
      assert_false member.dormant?
    end
  end

  def test_get_next_available_slots
    users(:f_mentor).user_setting.update_attributes(max_meeting_slots: 2)
    users(:f_mentor).reload

    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    invalidate_albers_calendar_meetings
    mentor = members(:f_mentor)
    student = users(:f_student)
    program = programs(:albers)
    time_now = Time.now.utc
    mentor.update_attribute(:will_set_availability_slots, false)
    assert mentor.reload.has_availability_between?(program, date_formatter(time_now - 5.days), date_formatter(time_now + 5.days, false), nil, {with_offset: true})

    mentor.update_attribute(:will_set_availability_slots, true)
    assert mentor.has_availability_between?(program, date_formatter(time_now - 5.days), date_formatter(time_now + 5.days, false), nil, {with_offset: true})
    assert_equal 1, mentor.mentoring_slots.size

    slot = mentor.mentoring_slots.first
    slot_start_time = time_now.beginning_of_day + 3.days
    slot_end_time = slot_start_time + 2.hours
    slot.update_attributes!(start_time: slot_start_time, end_time: slot_end_time)

    assert mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 5.days, false))
    assert_equal 1, mentor.mentoring_slots.size
    slots = mentor.get_next_available_slots(program)
    assert_equal 1, slots.size
    assert_equal [7200.0], slots.collect{|slot| (slot[:end].to_time - slot[:start].to_time)}
    assert mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 30.days, false), student)
    assert_equal 1, mentor.get_next_available_slots(program).size
    assert_false mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 1.days, false), student)
    assert_equal 1, mentor.get_next_available_slots(program).size
    assert mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 5.days, false), student)
    create_mentoring_slot(member: mentor, location: "Bangalore",
      start_time: slot_start_time + 1.day, end_time: slot_start_time + 1.days + 2.hours,
      repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)
    mentor.reload
    assert_equal 2, mentor.get_next_available_slots(program, 2, student, time_now - 10.days, time_now + 5.days).size
    assert mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 5.days, false), student)
    slots = mentor.get_next_available_slots(program, 3)
    assert_equal 2, slots.size
    assert_equal [7200.0, 7200.0], slots.collect{|slot| (slot[:end].to_time - slot[:start].to_time)}
    assert mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 5.days, false), student)
  end

  def test_get_next_available_slots_inadequate_slot
    users(:f_mentor).user_setting.update_attributes(max_meeting_slots: 2)
    users(:f_mentor).reload
    invalidate_albers_calendar_meetings
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    mentor = members(:f_mentor)
    student = users(:f_student)
    program = programs(:albers)

    mentor.update_attributes!(will_set_availability_slots: true)
    program.calendar_setting.update_attribute(:slot_time_in_minutes, 60)
    assert_equal 1, mentor.mentoring_slots.size
    slot = mentor.mentoring_slots.first
    slot_start_time = Time.now.beginning_of_day + 3.days
    slot_end_time = slot_start_time + 30.minutes
    slot.update_attributes!(start_time: slot_start_time, end_time: slot_end_time)
    slots = mentor.get_next_available_slots(program)
    assert_equal 0, slots.size
    assert_equal [], slots.collect{|slot| (slot[:end].to_time - slot[:start].to_time)}
    assert_false mentor.has_availability_between?(program, date_formatter(Time.now), date_formatter(Time.now + 30.days, false), student)
    create_mentoring_slot(member: mentor, location: "Bangalore",
      start_time: slot_start_time + 1.day, end_time: slot_start_time + 1.days + 1.hours,
      repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)
    mentor.reload
    assert_equal 1, mentor.get_next_available_slots(program, 2, student, Time.now - 10.days, Time.now + 5.days).size
  end

  def test_available_slots
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    member = members(:f_mentor)
    student = users(:f_student)
    program = programs(:albers)

    users(:f_mentor).user_setting.update_attributes(max_meeting_slots: 20)
    users(:f_mentor).reload

    assert_equal 1, member.mentoring_slots.size
    slot = member.mentoring_slots.first
    slot_start_time = Time.now.utc.beginning_of_day + 3.days
    slot_end_time = slot_start_time + 2.hours
    slot.update_attributes!(start_time: slot_start_time, end_time: slot_end_time)
    assert_equal 1, member.available_slots(program, slot_start_time - 1.day, slot_end_time + 1.day, student)
    create_mentoring_slot(member: member, location: "Bangalore",
      start_time: slot_start_time + 1.day, end_time: slot_start_time + 1.day + 2.hours,
      repeats: MentoringSlot::Repeats::NONE, repeats_on_week: nil)
    assert_equal 2, member.reload.available_slots(program, slot_start_time - 1.day, slot_end_time + 2.day, student)
  end

  def test_not_connected_for
    meetings(:f_mentor_mkr_student_daily_meeting).update_attribute(:active, false)
    start_day_time = Time.now.utc.beginning_of_day
    member = members(:f_mentor)
    assert_equal 5, member.meetings.size
    meeting = member.meetings.first
    update_recurring_meeting_start_end_date(meeting, (start_day_time + 1.hour), (start_day_time + 2.hour), {duration: 1.hour})
    assert member.not_connected_for?(10, programs(:nwen))
    assert_false member.not_connected_for?(10, programs(:albers))
    update_recurring_meeting_start_end_date(meeting, (start_day_time - 6.days), (start_day_time - 6.days + 1.hour), {duration: 1.hour})
    assert member.not_connected_for?(5, programs(:albers))
    assert_false member.not_connected_for?(10, programs(:albers))
    member_meeting = member.member_meetings.first
    member_meeting.update_attributes!(attending: false)
    assert member.not_connected_for?(10, programs(:albers))
  end

  def test_is_chronus_admin
    assert_false members(:f_admin).is_chronus_admin?
    members(:f_mentor).update_attribute(:email, SUPERADMIN_EMAIL)
    assert_false members(:f_mentor).reload.is_chronus_admin?

    members(:f_mentor).update_attribute(:email, "test@chronus.com")
    members(:f_admin).update_attribute(:email, SUPERADMIN_EMAIL)
    assert members(:f_admin).reload.is_chronus_admin?
  end

  def test_allowing_chronus_email_even_incase_of_domain_restriction
    security_setting = programs(:org_primary).security_setting
    assert_nil security_setting.email_domain
    security_setting.update_attributes!(email_domain: "SAMPLE.COM")

    members(:f_admin).email = "sample@chronus.com"
    assert_false members(:f_admin).valid?
    assert_equal "should be of sample.com", members(:f_admin).errors[:email][0]

    members(:f_admin).email = "sample@sample.com"
    assert members(:f_admin).valid?

    security_setting.update_attributes!(email_domain: "SAMPLE.com")
    members(:f_admin).email = "sample@sample.com"
    assert members(:f_admin).valid?

    members(:f_admin).email = SUPERADMIN_EMAIL
    assert members(:f_admin).valid?
  end

  def test_allowing_chronus_email_tohave_samepasswrod_even_incase_of_password_restriction
    security_setting = programs(:org_primary).security_setting
    assert security_setting.can_contain_login_name?
    security_setting.update_attributes!(can_contain_login_name: false)
    assert_false security_setting.can_contain_login_name?

    members(:f_admin).password = members(:f_admin).email
    members(:f_admin).password_confirmation = members(:f_admin).email
    assert_false members(:f_admin).valid?
    assert_equal "should not contain your name or your email address", members(:f_admin).errors[:password][0]

    members(:f_admin).email = SUPERADMIN_EMAIL
    members(:f_admin).password = members(:f_admin).email
    members(:f_admin).password_confirmation = members(:f_admin).email
    assert members(:f_admin).valid?
  end

  def test_accessible_programs
    assert_equal_unordered [programs(:albers), programs(:nwen), programs(:pbe), programs(:moderated_program)], members(:f_mentor).accessible_programs_for(members(:f_admin))
    assert_equal_unordered [programs(:albers), programs(:nwen), programs(:pbe)], members(:f_student).accessible_programs_for(members(:f_admin))
    assert_equal_unordered [programs(:albers), programs(:nwen), programs(:pbe)], members(:f_mentor).accessible_programs_for(members(:f_student))
    assert_equal_unordered [programs(:albers)], members(:f_mentor).accessible_programs_for(members(:f_mentor_student))
    assert_equal_unordered [programs(:albers), programs(:nwen), programs(:pbe)], members(:f_student).accessible_programs_for(members(:f_mentor))
    assert_equal_unordered [programs(:albers)], members(:f_student).accessible_programs_for(members(:f_mentor_student))

    mentor_role = programs(:albers).roles.find_by(name: RoleConstants::MENTOR_NAME)
    student_role = programs(:albers).roles.find_by(name: RoleConstants::STUDENT_NAME)
    mentor_role.remove_permission("view_students")
    assert_equal_unordered [programs(:nwen), programs(:pbe), programs(:albers)], members(:f_student).accessible_programs_for(members(:f_mentor))
    assert_equal_unordered [programs(:albers)], members(:f_student).accessible_programs_for(members(:f_mentor_student))
    assert_equal_unordered [programs(:albers), programs(:nwen), programs(:pbe)], members(:f_mentor).accessible_programs_for(members(:f_student))
    assert_equal_unordered [programs(:albers)], members(:f_mentor).accessible_programs_for(members(:f_mentor_student))

    student_role.remove_permission("view_mentors")
    assert_equal_unordered [programs(:nwen), programs(:pbe)], members(:f_mentor).accessible_programs_for(members(:f_student))
    assert_equal_unordered [programs(:albers)], members(:f_mentor).accessible_programs_for(members(:f_mentor_student))
    assert_equal_unordered [programs(:nwen), programs(:pbe), programs(:albers)], members(:f_student).accessible_programs_for(members(:f_mentor))
    assert_equal_unordered [programs(:albers)], members(:f_student).accessible_programs_for(members(:f_mentor_student))
  end

  def test_need_to_be_admin_to_edit
    gender_question = profile_questions(:profile_questions_8)
    user = users(:f_mentor)
    role = user.roles.find{|r| r.name == "mentor"}
    role_question = gender_question.role_questions.find{|rq| rq.role == role}

    # need not be admin
    assert_false role_question.admin_only_editable
    assert_false gender_question.need_to_be_admin_to_edit?(user)

    # need to be admin
    role_question.update_attribute(:admin_only_editable, true)
    assert role_question.reload.admin_only_editable
    assert gender_question.reload.need_to_be_admin_to_edit?(user)
  end

  def test_editable_by
    gender_question = profile_questions(:profile_questions_8)
    user = users(:f_mentor)
    role = user.roles.find{|r| r.name == "mentor"}
    role_question = gender_question.role_questions.find{|rq| rq.role == role}
    user = users(:f_mentor)

    # need not be admin
    assert_false role_question.admin_only_editable
    assert gender_question.editable_by?(user, users(:f_mentor))
    assert gender_question.editable_by?(user, users(:f_admin))

    # need to be admin
    role_question.update_attribute(:admin_only_editable, true)
    assert role_question.reload.admin_only_editable
    assert_false gender_question.reload.editable_by?(user, users(:f_mentor))
    assert gender_question.editable_by?(user, users(:f_admin))
  end

  def test_non_suspended
    organization = programs(:org_primary)
    organization.members.first.update_attribute(:state, Member::Status::SUSPENDED)
    assert_equal_unordered [Member::Status::ACTIVE, Member::Status::SUSPENDED, Member::Status::DORMANT], organization.members.pluck(:state).uniq
    assert_equal [Member::Status::ACTIVE, Member::Status::DORMANT], organization.members.non_suspended.pluck(:state).uniq

    organization = programs(:org_no_subdomain)
    assert_equal_unordered [Member::Status::ACTIVE, Member::Status::DORMANT], organization.members.non_suspended.pluck(:state).uniq
  end

  def test_fetch_or_create_password
    member = members(:f_mentor)
    assert_equal 0, member.passwords.size
    password = nil

    assert_difference "Password.count" do
      password = member.fetch_or_create_password
    end

    some_time = Time.now - 10.days
    password.update_attributes!(expiration_date: some_time)

    assert_no_difference "Password.count" do
      member.reload.fetch_or_create_password(false)
    end

    time_format = "%H: %M, %B %d, %Y"

    assert_equal password.expiration_date.strftime(time_format), member.passwords.last.expiration_date.strftime(time_format)

    assert_no_difference "Password.count" do
      member.reload.fetch_or_create_password
    end

    assert_not_equal password.expiration_date.strftime(time_format), member.passwords.last.expiration_date.strftime(time_format)
  end

  def test_ask_to_set_availability
    member = members(:f_mentor)

    assert_false member.ask_to_set_availability?

    member.update_attributes!(will_set_availability_slots: true)
    assert member.can_set_availability?
    assert member.will_set_availability_slots?
    assert member.ask_to_set_availability?
  end

  def test_remove_answers_from_unanswerable_questions
    member = members(:f_mentor)
    assert_no_difference "ProfileAnswer.count" do
      member.remove_answers_from_unanswerable_questions
    end
    assert_equal 14, member.profile_answers.size
    user = member.users.first
    user.role_names = RoleConstants::STUDENT_NAME
    user.save
    assert_difference "ProfileAnswer.count", -13 do
      member.remove_answers_from_unanswerable_questions
    end
    new_mem_ans = member.reload.profile_answers
    assert_equal [profile_answers(:location_chennai_ans)], new_mem_ans
    assert (new_mem_ans.first.profile_question.role_questions.collect(&:role_id) & Role.of_member(member).collect(&:id)).present?
  end

  def test_terms_and_conditions_accepted
    member = members(:f_mentor)
    organization = member.organization
    member.update_attribute(:terms_and_conditions_accepted, nil)
    member.reload

    assert !member.terms_and_conditions_accepted?, "expected member's T&C not be accepted if field is nil"

    member.accept_terms_and_conditions!
    assert member.terms_and_conditions_accepted?, "expected member's T&C be accepted"

    before = member.terms_and_conditions_accepted
    sleep 1.1
    member.accept_terms_and_conditions!
    assert_equal before, member.terms_and_conditions_accepted
  end


  def test_has_one_member_language
    member = members(:f_student)
    language = languages(:hindi)
    member_language = language.member_languages.create!(member_id: member.id)
    assert_equal member.member_language, member_language
    assert_difference "MemberLanguage.count", -1 do
      assert_difference "Member.count", -1 do
        member.destroy
      end
    end
  end

  def test_to_check_can_update_password
    member = members(:f_mentor)
    initial_password = member.crypted_password
    assert_equal 0, member.versions.size
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attributes!(password_history_limit: nil)
    assert member.can_update_password?
    member.password = "chronus123"
    member.password_confirmation = "chronus123"
    member.save!
    member.organization.security_setting.update_attributes!(password_history_limit: 2)
    assert_false member.can_update_password?
  end

  def test_is_an_existing_password_for_existing_user
    member = members(:f_mentor)
    initial_password = member.crypted_password
    assert_equal 0, member.versions.size
    member.password = "chronus123"
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attributes!(password_history_limit: 2)
    assert_false member.is_an_existing_password?
    member.password_confirmation = "chronus123"
    member.save!
    second_password = member.crypted_password
    assert_equal 1, member.versions.size
    member_versions = member.versions
    version_array = member_versions.first.modifications["crypted_password"]
    assert_equal [initial_password, second_password], version_array
    assert member.is_an_existing_password?

    member.password = "chronus123"
    member.password_confirmation = "chronus123"
    member.save!
    third_password = member.crypted_password
    assert_equal 1, member.versions.size
    member_versions = member.versions
    version_array = member_versions.first.modifications["crypted_password"]
    assert_equal [initial_password, third_password], version_array

    member.password = "mypassword"
    member.password_confirmation = "mypassword"
    member.save!
    fourth_password = member.crypted_password
    assert_equal 2, member.versions.size
    member_versions = member.versions
    version_array = member_versions.second.modifications["crypted_password"]
    assert_equal [second_password, fourth_password], version_array
    assert member.is_an_existing_password?
  end


  def test_is_an_existing_password_for_new_user
    member = create_member

    initial_password = member.crypted_password
    assert_equal 0, member.versions.size
    member.password = "chronus123"
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attributes!(password_history_limit: 2)
    member.reload
    member.password_confirmation = "chronus123"
    member.save!
    second_password = member.crypted_password
    assert_equal 1, member.versions.size
    member_versions = member.versions
    version_array = member_versions.first.modifications["crypted_password"]
    assert_equal [initial_password, second_password], version_array
    assert member.is_an_existing_password?
  end

  def test_is_an_existing_password_with_sha1_sha2_passwords
    member = members(:f_mentor)
    # update a sha1 password for the member for testing
    crypted_password = Member.sha1_digest('chronus', member.salt)
    member.update_columns(encryption_type: Member::EncryptionType::SHA1, crypted_password: crypted_password)

    # Check if the current password size is the sha1 encryption size(40)
    assert_equal 40, member.crypted_password.size

    # Change the password. This time it should be sha2 encrypted
    member.password = 'chronus123'
    member.password_confirmation = 'chronus123'
    member.save!
    # Check if the current password size is the sha2 encryption size(128) and the encryption type is sha2
    assert_equal 128, member.crypted_password.size
    assert_equal Member::EncryptionType::SHA2, member.encryption_type

    # Set the password history limit to 3
    security_setting = programs(:org_primary).security_setting
    security_setting.update_attributes!(password_history_limit: 3)

    # Add another sha2 encrypted password
    member.password = 'chronus1'
    member.password_confirmation = 'chronus1'
    assert_false member.reload.is_an_existing_password?
    member.save!

    # Now we have 1 sha1 password and 2 sha2 passwords in the versions table. Check if is_an_existing_password is working for all
    member.password = 'chronus'
    assert member.is_an_existing_password?
    member.password = 'chronus123'
    assert member.is_an_existing_password?
    member.password = 'chronus1'
    assert member.is_an_existing_password?
    member.password = 'chronus2'
    assert_false member.is_an_existing_password?
  end

  def test_migrate_pwd_to_intermediate
    # This is to test the migrate_pwd_to_intermediate method which is used in migration.
    # It encrypts existing SHA1 password to SHA2 and set the encryption_type to intermediate
    member = members(:f_mentor)
    # update a sha1 password for the member for testing
    crypted_password = Member.sha1_digest('chronus', member.salt)
    member.update_columns(encryption_type: Member::EncryptionType::SHA1, crypted_password: crypted_password)

    sha1_crypted_password = member.crypted_password
    member.migrate_pwd_to_intermediate
    assert Member.sha1_sha2_digest('chronus', member.salt), member.crypted_password
    assert Member::EncryptionType::INTERMEDIATE, member.encryption_type
  end

  def test_encrypt_with_sha2
    # This is to test the encryption_with_sha2 used while logging in.
    # It encrypts existing password to SHA2 and set the encryption_type to sha2
    member = members(:f_mentor)
    # update a sha1 password for the member for testing
    crypted_password = Member.sha1_digest('chronus', member.salt)
    member.update_columns(encryption_type: Member::EncryptionType::SHA1, crypted_password: crypted_password)

    sha1_crypted_password = member.crypted_password
    member.encrypt_with_sha2('chronus')
    assert Member.sha2_digest('chronus', member.salt), member.crypted_password
    assert Member::EncryptionType::SHA2, member.encryption_type
  end

  def test_short_time_zone
    member = Member.first
    assert_nil member.time_zone
    assert_equal "UTC", member.short_time_zone
    member.update_attributes!(time_zone: "Etc/UTC")
    assert_equal "UTC", member.short_time_zone
    member.update_attributes!(time_zone: "Asia/Karachi")
    assert_equal "PKT", member.short_time_zone
  end

  def test_sorted_by_answer_for_file_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id

    question = profile_questions(:mentor_file_upload_q)

    f_admin.save_answer!(question, fixture_file_upload(File.join('files', 'test_file.css')))
    f_mentor.save_answer!(question, fixture_file_upload(File.join('files', 'test_file.csv')))
    f_student.save_answer!(question, fixture_file_upload(File.join('files', 'test_email_source.eml')))

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id])

    assert_equal [f_student_member_id, f_admin_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_admin_member_id, f_student_member_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_work_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id

    question = profile_questions(:profile_questions_7)

    default_education_options = {
      job_title: 'A',
      start_year: 1990,
      end_year: 1995,
      company: 'B'
    }

    create_experience_answers(f_admin, question, [
      default_education_options.merge(job_title: 'Bu', end_year:2001)
    ])
    create_experience_answers(f_mentor, question, [
      default_education_options.merge(job_title: 'A', end_year:2001),
      default_education_options.merge(job_title: 'Bz', end_year:2002)
    ])
    create_experience_answers(f_student, question, [
      default_education_options.merge(job_title: 'ba', end_year:2001)
    ])

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id])

    assert_equal [f_student_member_id, f_admin_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_admin_member_id, f_student_member_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_education_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id

    question = profile_questions(:profile_questions_6)

    default_education_options = {
      school_name: 'A',
      degree: 'A',
      major: 'Mech',
      graduation_year: 2010
    }

    create_education_answers(f_admin, question, [
      default_education_options.merge(school_name: 'bu', degree: 'A')
    ])
    create_education_answers(f_mentor, question, [
      default_education_options.merge(school_name: 'A', degree: 'A', graduation_year: 2005),
      default_education_options.merge(school_name: 'bz', degree: 'B')
    ])
    create_education_answers(f_student, question, [
      default_education_options.merge(school_name: 'Ba', degree: 'B')
    ])

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id])

    assert_equal [f_student_member_id, f_admin_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_admin_member_id, f_student_member_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_publication_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id

    question = create_question(question_type: ProfileQuestion::Type::PUBLICATION, question_text: "Publication", organization: programs(:org_primary))

    default_publication_options = {
      title: 'A',
      authors: 'A',
      publisher: 'Mech',
      year: 2010,
      month: 1,
      day: 1,
    }

    create_publication_answers(f_admin, question, [
      default_publication_options.merge(title: 'bu', authors: 'A')
    ])
    create_publication_answers(f_mentor, question, [
      default_publication_options.merge(title: 'A', authors: 'A', year: 2005),
      default_publication_options.merge(title: 'bz', authors: 'B')
    ])
    create_publication_answers(f_student, question, [
      default_publication_options.merge(title: 'Ba', authors: 'B')
    ])

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id])

    assert_equal [f_student_member_id, f_admin_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_admin_member_id, f_student_member_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_manager_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_mentor.member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id

    question = programs(:org_primary).profile_questions.manager_questions.first

    default_manager_options = {
      first_name: 'A',
      last_name: 'B',
      email: 'cemail@example.com'
    }

    create_manager(f_admin, question, default_manager_options)
    create_manager(f_mentor, question, default_manager_options.merge(first_name: 'b', last_name: 'b'))
    create_manager(f_student, question, default_manager_options.merge(first_name: 'b', last_name: 'a'))

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id])

    assert_equal [f_admin_member_id, f_student_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_student_member_id, f_admin_member_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_text_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id

    question = profile_questions(:profile_questions_4)

    f_admin.save_answer!(question, 'Bu')
    f_mentor.save_answer!(question, 'Bz')
    f_student.save_answer!(question, 'ba')

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id])

    assert_equal [f_student_member_id, f_admin_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_admin_member_id, f_student_member_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_sorted_by_answer_for_date_question
    f_admin   = users(:f_admin)
    f_mentor  = users(:f_mentor)
    f_student = users(:f_student)
    f_mentor_student = users(:f_mentor_student)
    f_admin_member_id = f_admin.member.id
    f_mentor_member_id = f_mentor.member.id
    f_student_member_id = f_student.member.id
    f_mentor_student_id = f_mentor_student.id

    question = profile_questions(:date_question)

    f_admin.save_answer!(question, '12 July, 2018')
    f_mentor.save_answer!(question, '12 June, 2019')
    f_student.save_answer!(question, '13 December, 1956')
    f_mentor_student.save_answer!(question, '')

    scope = Member.where(id: [f_admin_member_id, f_mentor_member_id, f_student_member_id, f_mentor_student_id])

    assert_equal [f_mentor_student_id, f_student_member_id, f_admin_member_id, f_mentor_member_id], Member.sorted_by_answer(scope, question, "asc").map(&:id)
    assert_equal [f_mentor_member_id, f_admin_member_id, f_student_member_id, f_mentor_student_id], Member.sorted_by_answer(scope, question, "desc").map(&:id)
  end

  def test_has_many_three_sixty_surveys
    member = members(:f_admin)
    assert_equal 1, member.three_sixty_surveys.size
    assert_no_difference "ThreeSixty::Survey.count" do
      member.destroy
    end
  end

  def test_has_many_three_sixty_survey_assessees
    member = members(:f_admin)
    assert_equal 1, member.three_sixty_survey_assessees.size
    assert_difference "ThreeSixty::SurveyAssessee.count", -1 do
      member.destroy
    end
  end

  def test_three_sixty_survey_reviewers
    member = members(:f_admin)
    assert_equal 5, member.three_sixty_survey_reviewers.size
  end

  def test_sorted_by_program_roles
    ##################################################################
    # f_admin = ["Albers Mentor Program", "Moderated Program", "NWEN"]
    # f_mentor = ["Albers Mentor Program", "NWEN"]
    # f_mentor_student = ["Albers Mentor Program"]
    ##################################################################

    f_admin   = members(:f_admin)
    f_mentor  = members(:f_mentor)
    f_mentor_student = members(:f_mentor_student)

    scope = Member.where(id: [f_admin, f_mentor, f_mentor_student])

    assert_equal [f_mentor_student.id, f_admin.id, f_mentor.id], Member.sorted_by_program_roles(scope, "asc").collect(&:id)
    assert_equal [f_admin.id, f_mentor.id, f_mentor_student.id], Member.sorted_by_program_roles(scope, "desc").collect(&:id)
  end

  def test_has_many_job_logs
    member = members(:f_mentor)
    job_logs_count = member.job_logs.count
    member.users.each{|user| job_logs_count += user.job_logs.count}
    assert_difference "JobLog.count", -(job_logs_count) do
      assert_difference "Member.count", -1 do
        member.destroy
      end
    end
  end

  def test_visible_to
    member1 = create_member(last_name: "first_test_member")
    user11 = create_user(member: member1, role_names: ['student'], program: programs(:albers))

    member2 = create_member(last_name: "second_test_member")
    user21 = create_user(member: member2, role_names: ['student'], program: programs(:albers))

    member3 = create_member(last_name: "third_test_member")
    user31 = create_user(member: member3, role_names: ['student'], program: programs(:ceg))

    assert member1.visible_to?(member2)

    fetch_role(:albers, :student).remove_permission('view_students')
    assert_false user11.reload.can_view_students?
    assert_false member1.visible_to?(member2)

    user21.add_role(RoleConstants::MENTOR_NAME)
    assert member1.visible_to?(member2)

    fetch_role(:albers, :mentor).remove_permission('view_students')
    assert_false member1.visible_to?(member2)

    user12 = create_user(member: member1, role_names: ['student'], program: programs(:moderated_program))
    assert_false member1.reload.visible_to?(member2)

    user22 = create_user(member: member2, role_names: ['student'], program: programs(:moderated_program))
    assert member1.visible_to?(member2.reload)

    fetch_role(:moderated_program, :student).remove_permission('view_students')
    assert_false member1.visible_to?(member2)

    assert_false member2.visible_to?(member3)
    assert_false member3.visible_to?(member2)

    member2.promote_as_admin!

    assert member1.visible_to?(member2)
    assert member2.visible_to?(member3)
    assert member3.visible_to?(member2)
  end

  def test_prevent_matching_enabled
    member = members(:f_student)
    program = programs(:albers)
    program.update_attributes(prevent_manager_matching: true)
    assert member.prevent_matching_enabled?
    program.update_attributes(prevent_manager_matching: false)
    member.reload
    assert_false member.prevent_matching_enabled?

    program.engagement_type = nil
    program.enable_feature(FeatureName::CALENDAR, false)
    program.save!
    program.update_attributes(prevent_manager_matching: true)
    member.reload
    assert_false member.prevent_matching_enabled?

    program = programs(:primary_portal)
    member = members(:portal_employee)
    assert_false member.prevent_matching_enabled?
  end

  def test_prevent_manager_matching_level
    member = members(:f_student)
    program = programs(:albers)
    program1 = programs(:nwen)
    program.update_attributes(prevent_manager_matching: true, manager_matching_level: -1)
    program1.update_attributes(prevent_manager_matching: true, manager_matching_level: 1)
    member.reload
    assert_equal member.prevent_manager_matching_level, -1

    program.update_attributes(prevent_manager_matching: true, manager_matching_level: 2)
    member.reload
    assert_equal member.prevent_manager_matching_level, 2

    program = programs(:primary_portal)
    member = members(:portal_employee)
    assert_nil member.prevent_manager_matching_level
  end

  def test_time_zone
    member = members(:f_student)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :time_zone do
      member.update_attributes!(time_zone: "ProbePhising")
    end
    member.update_attributes!(time_zone: "Asia/Kolkata")
    assert_equal "Asia/Kolkata", member.time_zone
    member.update_attributes!(time_zone: nil)
    assert_nil member.time_zone
    member.update_attributes!(time_zone: "")
    assert_blank member.time_zone
  end

  def test_by_email_or_name
    member = members(:f_student)
    organization = member.organization
    assert Member.by_email_or_name(member.name_with_email, organization).include? member
    assert Member.by_email_or_name(member.name, organization).include? member
    assert Member.by_email_or_name(member.email, organization).include? member
    assert Member.by_email_or_name(member.first_name, organization).include? member
    assert Member.by_email_or_name(member.last_name, organization).include? member
    assert Member.by_email_or_name("", organization).include? member
  end

  def test_has_many_mobile_devices
    member = members(:f_student)
    assert_equal [], member.mobile_devices
    member.set_mobile_access_tokens!("Claire!!")
    assert_equal ["Claire!!"], member.mobile_devices.collect(&:device_token)
    assert_difference "MobileDevice.count", -1 do
      member.destroy
    end
  end

  def test_set_mobile_access_tokens
    member = members(:f_student)
    assert_equal [], member.mobile_devices

    assert_difference "MobileDevice.count" do
      member.set_mobile_access_tokens!("Skyler!!")
    end

    assert_difference "MobileDevice.count" do
      member.set_mobile_access_tokens!("Alicia Florick!!")
    end

    assert_equal ["Skyler!!", "Alicia Florick!!"], member.mobile_devices.collect(&:device_token)

    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens!("Alicia Florick!!")
    end

    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens!("Skyler!!")
    end
  end

  def test_prepare_answer_hash
    program = programs(:albers)
    member = members(:f_mentor)
    question = profile_questions(:publication_q)
    answer = member.answer_for(question)

    result_hash = Member.prepare_answer_hash([member.id], [question.id])
    assert_equal [member.id], result_hash.keys
    assert_equal [question.id], result_hash.values.first.keys
    assert_equal [answer], result_hash.values.first.values.flatten
  end

  def test_members_with_role_names_and_deactivation_dates
    organization = programs(:org_anna_univ)
    member1 = members(:anna_univ_mentor)
    member2 = members(:inactive_user)
    ceg_mentor_role = programs(:ceg).find_role(RoleConstants::MENTOR_NAME)
    psg_mentor_role = programs(:psg).find_role(RoleConstants::MENTOR_NAME)

    result_hash = Member.members_with_role_names_and_deactivation_dates([member1.id, member2.id], organization, only_suspended_status: true)
    assert_equal ["CEG Mentor Program", "psg"], result_hash[member1.id].keys
    assert_equal_hash( { "user_suspended" => false, "roles" => ["Mentor"] }, result_hash[member1.id]["CEG Mentor Program"])
    assert_equal_hash( { "user_suspended" => false, "roles" => ["Mentor"] }, result_hash[member1.id]["psg"])
    assert_equal_hash( { "psg" => { "user_suspended" => true, "roles" => ["Mentor"] } }, result_hash[member2.id])

    result_hash = Member.members_with_role_names_and_deactivation_dates([member1.id, member2.id], organization)
    assert_equal ["CEG Mentor Program", "psg"], result_hash[member1.id].keys
    assert_equal_hash( { "status" => "active", "roles" => ["Mentor"] }, result_hash[member1.id]["CEG Mentor Program"])
    assert_equal_hash( { "status" => "active", "roles" => ["Mentor"] }, result_hash[member1.id]["psg"])
    assert_equal_hash( { "psg" => { "status" => "suspended", "roles" => ["Mentor"] } }, result_hash[member2.id])

    result_hash = Member.members_with_role_names_and_deactivation_dates([member1.id, member2.id], organization, role_ids_needed: true)
    assert_equal ["CEG Mentor Program", "psg"], result_hash[member1.id].keys
    assert_equal_hash( { "status" => "active", "roles" => ["Mentor#{UNDERSCORE_SEPARATOR}#{ceg_mentor_role.id}"] }, result_hash[member1.id]["CEG Mentor Program"])
    assert_equal_hash( { "status" => "active", "roles" => ["Mentor#{UNDERSCORE_SEPARATOR}#{psg_mentor_role.id}"] }, result_hash[member1.id]["psg"])
    assert_equal_hash( { "psg" => { "status" => "suspended", "roles" => ["Mentor#{UNDERSCORE_SEPARATOR}#{psg_mentor_role.id}"] } }, result_hash[member2.id])
  end

  def test_get_groups_count_map_for_status
    member = members(:f_mentor)
    active_groups_count_map = Member.get_groups_count_map_for_status([member.id, members(:f_admin).id], Group::Status::ACTIVE_CRITERIA)
    assert_equal_hash( { member.id => 3 } , active_groups_count_map)

    group = groups(:mygroup)
    group.terminate!(users(:f_admin), "Test reason", group.program.permitted_closure_reasons.first.id)
    active_groups_count_map = Member.get_groups_count_map_for_status([member.id], Group::Status::ACTIVE_CRITERIA)
    assert_equal_hash( { member.id => 2 } , active_groups_count_map)

    closed_groups_count_map = Member.get_groups_count_map_for_status([member.id], Group::Status::CLOSED)
    assert_equal_hash( { member.id => 1 } , closed_groups_count_map)
  end

  def test_has_availability_for_mentor_preferring_contact_by_message
    mentor = members(:f_mentor)
    program = programs(:albers)
    time_now = Time.now.utc
    mentor.update_attribute(:will_set_availability_slots, false)
    assert mentor.reload.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 5.days, false))

    mentor.update_attribute(:will_set_availability_slots, true)
    assert_false mentor.has_availability_between?(program, date_formatter(time_now), date_formatter(time_now + 5.days, false))
  end

  def test_set_time_with_offset
    program = programs(:albers)
    Timecop.freeze(Time.utc(2015, 10, 23, 12)) do
      time = Time.now.utc.beginning_of_day
      assert_equal Time.utc(2015, 10, 23, 12), Member.set_time_with_offset(time, program)
    end
  end

  def test_set_time_with_offset_for_24_hrs
    program = programs(:albers)
    c = program.calendar_setting
    c.advance_booking_time = 24
    c.save!
    Timecop.freeze(Time.utc(2015, 10, 23, 12)) do
      time = Time.now.utc.beginning_of_day
      assert_equal Time.utc(2015, 10, 24, 12), Member.set_time_with_offset(time, program)
    end
  end

  def test_sent_messages
    member = members(:f_admin)
    assert_equal_unordered [messages(:third_admin_message), messages(:reply_to_offline_user)], member.sent_messages
    messages(:third_admin_message).update_attribute(:auto_email, true)
    assert_equal [messages(:reply_to_offline_user)], member.reload.sent_messages
  end

  def test_should_not_validate_with_mx_on_create
    invalid_email = "aobad@servershouldntexist.com"
    # Email should be of valid format but should fail MX test
    assert ValidatesEmailFormatOf::validate_email_format(invalid_email, check_mx: false).nil?
    assert_nothing_raised do
      member = programs(:org_primary).members.new
      member.email = invalid_email
      member.password = "password"
      member.password_confirmation = "password"
      member.last_name = "last_name"
      member.first_name = "first name"
      member.save!
    end
  end

  def test_can_signin
    member = members(:f_student)
    assert_not_empty member.auth_configs
    assert member.can_signin?

    member.stubs(:auth_configs).returns(AuthConfig.where(id: 0))
    assert_false member.can_signin?
  end

  def test_has_many_dismissed_rollout_emails
    m = members(:student_8)
    re = m.dismissed_rollout_emails.create!
    assert_equal [re], m.dismissed_rollout_emails
    assert_difference 'RolloutEmail.count', -1 do
      m.destroy
    end
  end

  def test_save_answer_new
    member = members(:f_student)
    question = profile_questions(:single_choice_q)
    assert_difference "ProfileAnswer.count" do
      assert member.save_answer!(question, "opt_2"), "expected save_answer to success"
    end
    assert_equal "opt_2", member.answer_for(question).answer_value
  end

  def test_save_answer_exisiting
    member = users(:f_mentor).member
    existing_ans_1 = member.answer_for(profile_questions(:multi_choice_q))
    existing_ans_2 = member.answer_for(profile_questions(:single_choice_q).reload)

    assert_equal ['Stand', 'Run'], existing_ans_1.answer_value
    assert_equal "opt_1", existing_ans_2.answer_value
    assert_no_difference("ProfileAnswer.count") do
      assert member.save_answer!(profile_questions(:multi_choice_q), ["Walk"])
      assert member.save_answer!(profile_questions(:single_choice_q), "opt_2")
    end

    assert_equal ['Walk'], existing_ans_1.reload.answer_value
    assert_equal 'opt_2', existing_ans_2.reload.answer_value
  end
  def test_update_education_answers_empty_for_pending
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_education_q)
    role_q = question.role_questions.first
    role_q.update_attributes(required: true)
    member.educations.all.collect(&:destroy)
    e = assert_raise(ActiveRecord::RecordInvalid) do
      member.update_education_answers(question, {"new_education_attributes" =>[], "existing_education_attributes" =>{}}, user, false)
    end
    assert_match(/Educations can't be blank/, e.message)
    member.update_education_answers(question, {"new_education_attributes" =>[], "existing_education_attributes" =>{}}, user, true)
    assert_equal 0, member.reload.educations.length
  end

  def test_update_experience_answers_empty_for_pending
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    role_q = question.role_questions.first
    role_q.update_attributes(required: true)
    member.experiences.all.collect(&:destroy)
    e = assert_raise(ActiveRecord::RecordInvalid) do
      member.update_experience_answers(question, {"new_experience_attributes" =>[], "existing_experience_attributes" =>{}}, user, false)
    end
    assert_match(/Experiences can't be blank/, e.message)
    member.update_experience_answers(question, {"new_experience_attributes" =>[], "existing_experience_attributes" =>{}}, user, true)
    assert_equal 0, member.reload.experiences.length
  end

  def test_update_publication_answers_empty_for_pending
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_publication_q)
    role_q = question.role_questions.first
    role_q.update_attributes(required: true)
    member.publications.all.collect(&:destroy)
    e = assert_raise(ActiveRecord::RecordInvalid) do
      member.update_publication_answers(question, {"new_publication_attributes" =>[], "existing_publication_attributes" =>{}}, user, false)
    end
    assert_match(/Publications can't be blank/, e.message)
    member.update_publication_answers(question, {"new_publication_attributes" =>[], "existing_publication_attributes" =>{}}, user, true)
    assert_equal 0, member.reload.publications.length
  end

  def test_update_manager_answers_empty_for_pending
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:manager_q)
    role_q = question.role_questions.first
    role_q.update_attributes(required: true)
    manager = member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager
    manager.destroy
    e = assert_raise(ActiveRecord::RecordInvalid) do
      member.update_manager_answers(question, {"new_manager_attributes" =>[], "existing_manager_attributes" =>{}}, user, false)
    end
    assert_match(/Manager can't be blank/, e.message)
    member.update_manager_answers(question, {"new_manager_attributes" =>[], "existing_manager_attributes" =>{}}, user, true)
    assert_blank member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }
  end

  def test_update_education_answers_only_existing_education
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_education_q)
    member.educations.all.collect(&:destroy)
    edu1 = create_education(member, question, graduation_year: 2000)
    edu2 = create_education(member, question, graduation_year: 2001)
    assert_equal "SSV, BTech, IT\n SSV, BTech, IT", user.answer_for(question).answer_text

    # edu2 is not included in the new list. So it will be deleted. edu1 is there and hence it will be updated
    assert_equal 2, member.reload.educations.length
    member.update_education_answers(question, {"existing_education_attributes" =>{edu1.id.to_s => {school_name: "SSV", degree: "MS", major: "Cs", graduation_year: "2010"}}}, user)

    assert_equal 1, member.reload.educations.length

    edu1.reload
    assert_equal "MS", edu1.degree
    assert_equal "Cs", edu1.major
    assert_equal 2010, edu1.graduation_year
    assert_equal "SSV", edu1.school_name
    assert_equal "SSV, MS, Cs", user.answer_for(question).answer_text
  end

  def test_update_education_answer_new_member_attribute
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_education_q)
    member.educations.all.collect(&:destroy)
    edu1 = create_education(member, question, graduation_year: 2000)
    edu2 = create_education(member, question, graduation_year: 2001)
    assert_equal "SSV, BTech, IT\n SSV, BTech, IT", user.answer_for(question).answer_text

    assert_equal 2, member.reload.educations.length
    member.update_education_answers(question, {"new_education_attributes" =>[{"1" => {school_name: "SSV", graduation_year: 2000, degree: "10th", major: "CS"}}]}, user)
    # not a new member
    assert_equal 1, member.reload.educations.length
    assert_equal "SSV, 10th, CS", user.answer_for(question).answer_text

    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Profile question has already been taken" do
      # here passing existing record as new and trying to create new education answer
      member.update_education_answers(question, {"new_education_attributes" =>[{"1" => {school_name: "SSV", graduation_year: 2000, degree: "10th", major: "CS"}}],
                                               "existing_education_attributes" =>{edu1.id.to_s => {school_name: "SSV", degree: "MS", major: "Cs", graduation_year: "2010"}}}, user, false, true)
    end

    ProfileAnswer.any_instance.expects(:build_new_education_answers)
    member.update_education_answers(question, {"new_education_attributes" =>[{"1" => {school_name: "SSVV", graduation_year: 2000, degree: "10th", major: "CS"}}]}, user)
  end

  def test_update_education_experience_publication_manager_without_passing_user
    #education type
    member = members(:f_mentor)
    question = profile_questions(:multi_education_q)
    member.educations.all.collect(&:destroy)
    edu1 = create_education(member, question, graduation_year: 2000)
    edu2 = create_education(member, question, graduation_year: 2001)
    assert_equal "SSV, BTech, IT\n SSV, BTech, IT", member.answer_for(question).answer_text
    assert_equal 2, member.reload.educations.length
    member.update_education_answers(question, {"new_education_attributes" =>[{"1" => {school_name: "SSV", graduation_year: 2000, degree: "10th", major: "CS"}}], "existing_education_attributes" =>{edu1.id.to_s => {school_name: "SSV", degree: "MS", major: "Cs", graduation_year: "2010"}}})

    assert_equal 2, member.reload.educations.length

    edu1.reload
    assert_equal "MS", edu1.degree
    assert_equal "Cs", edu1.major
    assert_equal 2010, edu1.graduation_year
    assert_equal "SSV", edu1.school_name
    assert_equal "SSV, MS, Cs\n SSV, 10th, CS", member.answer_for(question).answer_text

    #experience Type question
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    exp1 = create_experience(member, question, start_year: 2000)
    exp2 = create_experience(member, question, start_year: 2001)
    assert_equal "SDE, MSFT\n SDE, MSFT", member.answer_for(question).answer_text

    assert_equal 2, member.reload.experiences.length
    member.update_experience_answers(question, {"new_experience_attributes" =>["1" => {start_year: 1990, end_year: 2000, company: "NewComp", job_title: "NewJob"}], "existing_experience_attributes" =>{exp1.id.to_s =>{company: "Chronus", start_year: 2003, end_year: 2004, job_title: "SDE"}}})
    assert_equal 2, member.reload.experiences.length

    exp1.reload
    assert_equal "Chronus", exp1.company
    assert_equal 2003, exp1.start_year
    assert_equal 2004, exp1.end_year
    assert_equal "SDE", exp1.job_title
    assert_equal "SDE, Chronus\n NewJob, NewComp", member.answer_for(question).answer_text

    #publication
    question = profile_questions(:multi_publication_q)
    member.publications.all.collect(&:destroy)
    pub1 = create_publication(member, question, day: 1, month: 1, year: 2010)
    pub2 = create_publication(member, question, day: 1, month: 1, year: 2012)
    assert_equal "Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication", member.answer_for(question).answer_text

    assert_equal 2, member.reload.publications.length
    member.update_publication_answers(question, {"new_publication_attributes" =>["1" => {title: 'Pub1', day: 1, month: 1, year: 2010, authors: 'New author'}], "existing_publication_attributes" =>{pub1.id.to_s =>{title: "Pub exist", day: 1, month: 1, year: 2009}}})
    assert_equal 2, member.reload.publications.length
    new_pub = Publication.last
    pub1.reload
    assert_equal "Pub exist", pub1.title
    assert_equal 'January 01, 2009', pub1.formatted_date
    assert_equal 'Pub1', new_pub.title
    assert_equal 'January 01, 2010', new_pub.formatted_date
    assert_equal "Pub exist, Publisher ltd., http://public.url, Author, Very useful publication\n Pub1, , , New author, ", member.answer_for(question).answer_text

    #manager
    question = profile_questions(:manager_q)
    member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    manager = create_manager(member, question)
    assert_equal "Manager Name, manager@example.com", member.answer_for(question).answer_text

    member.update_manager_answers(question, {"existing_manager_attributes" =>{manager.id.to_s =>{first_name: "Man1", last_name: "Last1", email: "manager@example.com"}}})

    manager.reload
    assert_equal "Man1", manager.first_name
    assert_equal "Last1", manager.last_name
    assert_equal "Man1 Last1, manager@example.com", member.answer_for(question).answer_text

  end

  def test_update_education_answers_only_new_education
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_education_q)
    member.educations.all.collect(&:destroy)
    edu1 = create_education(member, question, graduation_year: 2000)
    edu2 = create_education(member, question, graduation_year: 2001)
    assert_equal "SSV, BTech, IT\n SSV, BTech, IT", user.answer_for(question).answer_text

    # edu2 is not included in the new list. So it will be deleted. edu1 is there and hence it will be updated
    assert_equal 2, member.reload.educations.length
    member.update_education_answers(question, {"new_education_attributes" =>[{"1" => {school_name: "SSV", graduation_year: 2000, degree: "10th", major: "CS"}}]}, user)

    assert_equal 1, member.reload.educations.length
    new_edu = member.educations.first
    assert_equal "10th", new_edu.degree
    assert_equal "CS", new_edu.major
    assert_equal 2000, new_edu.graduation_year
    assert_equal "SSV", new_edu.school_name
    assert_equal "SSV, 10th, CS", user.answer_for(question).answer_text
  end


  def test_update_education_answers_both_new_and_existing_education
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_education_q)
    member.educations.all.collect(&:destroy)
    edu1 = create_education(member, question, graduation_year: 2000)
    edu2 = create_education(member, question, graduation_year: 2001)
    assert_equal "SSV, BTech, IT\n SSV, BTech, IT", user.answer_for(question).answer_text

    # edu2 is not included in the new list. So it will be deleted. edu1 is there and hence it will be updated
    assert_equal 2, member.reload.educations.length
    member.update_education_answers(question, {"new_education_attributes" =>[{"1" => {school_name: "SSV", graduation_year: 2000, degree: "10th", major: "CS"}}], "existing_education_attributes" =>{edu1.id.to_s => {school_name: "SSV", degree: "MS", major: "Cs", graduation_year: "2010"}}}, user)

    assert_equal 2, member.reload.educations.length

    edu1.reload
    assert_equal "MS", edu1.degree
    assert_equal "Cs", edu1.major
    assert_equal 2010, edu1.graduation_year
    assert_equal "SSV", edu1.school_name
    assert_equal "SSV, MS, Cs\n SSV, 10th, CS", user.answer_for(question).answer_text
  end


  def test_update_education_answers_no_new_and_existing_education
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_education_q)
    member.educations.all.collect(&:destroy)
    edu1 = create_education(member, question, graduation_year: 2000)
    edu2 = create_education(member, question, graduation_year: 2001)
    assert_equal "SSV, BTech, IT\n SSV, BTech, IT", user.answer_for(question).answer_text

    # edu2 is not included in the new list. So it will be deleted. edu1 is there and hence it will be updated
    assert_equal 2, member.reload.educations.length
    member.update_education_answers(question, {}, user)

    assert_equal 0, member.reload.educations.length
    assert_nil user.answer_for(question)
  end

  def test_update_experience_answers_only_existing_experience
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    exp1 = create_experience(member, question, start_year: 2000)
    exp2 = create_experience(member, question, start_year: 2001)
    assert_equal "SDE, MSFT\n SDE, MSFT", user.answer_for(question).answer_text

    assert_equal 2, member.reload.experiences.length
    member.update_experience_answers(question, {"existing_experience_attributes" =>{exp1.id.to_s =>{company: "Chronus", start_year: 2003, end_year: 2004, job_title: "SDE"}}}, user)
    assert_equal 1, member.reload.experiences.length

    exp1.reload
    assert_equal "Chronus", exp1.company
    assert_equal 2003, exp1.start_year
    assert_equal 2004, exp1.end_year
    assert_equal "SDE", exp1.job_title
    assert_equal "SDE, Chronus", user.answer_for(question).answer_text
  end

  def test_update_experience_answers_only_new_experience
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    exp1 = create_experience(member, question, start_year: 2000)
    exp2 = create_experience(member, question, start_year: 2001)
    assert_equal "SDE, MSFT\n SDE, MSFT", user.answer_for(question).answer_text

    assert_equal 2, member.reload.experiences.length
    member.update_experience_answers(question, {"new_experience_attributes" =>["1" => {start_year: 1990, end_year: 2000, company: "NewComp", job_title: "NewJob"}]}, user)
    assert_equal 1, member.reload.experiences.length

    new_exp = member.experiences.first
    assert_equal 1990, new_exp.start_year
    assert_equal 2000, new_exp.end_year
    assert_equal "NewComp", new_exp.company
    assert_equal "NewJob", new_exp.job_title
    assert_equal "NewJob, NewComp", user.answer_for(question).answer_text
  end

  def test_update_experience_answers_both_new_and_existing_experience
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    exp1 = create_experience(member, question, start_year: 2000)
    exp2 = create_experience(member, question, start_year: 2001)
    assert_equal "SDE, MSFT\n SDE, MSFT", user.answer_for(question).answer_text

    assert_equal 2, member.reload.experiences.length
    member.update_experience_answers(question, {"new_experience_attributes" =>["1" => {start_year: 1990, end_year: 2000, company: "NewComp", job_title: "NewJob"}], "existing_experience_attributes" =>{exp1.id.to_s =>{company: "Chronus", start_year: 2003, end_year: 2004, job_title: "SDE"}}}, user)
    assert_equal 2, member.reload.experiences.length

    exp1.reload
    assert_equal "Chronus", exp1.company
    assert_equal 2003, exp1.start_year
    assert_equal 2004, exp1.end_year
    assert_equal "SDE", exp1.job_title
    assert_equal "SDE, Chronus\n NewJob, NewComp", user.answer_for(question).answer_text
  end

  def test_update_experience_answers_new_member_attribute
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    exp1 = create_experience(member, question, start_year: 2000)
    exp2 = create_experience(member, question, start_year: 2001)
    assert_equal "SDE, MSFT\n SDE, MSFT", user.answer_for(question).answer_text

    assert_equal 2, member.reload.experiences.length
    member.update_experience_answers(question, {"new_experience_attributes" =>["1" => {start_year: 1990, end_year: 2000, company: "NewComp", job_title: "NewJob"}]}, user)
    assert_equal 1, member.reload.experiences.length
    assert_equal "NewJob, NewComp", user.answer_for(question).answer_text
      # "new_experience_attributes" =>["1" => {start_year: 1990, end_year: 2000, company: "NewComp", job_title: "NewJob"}],
    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Profile question has already been taken" do
      # here passing existing record as new and trying to create new experience answer
      member.update_experience_answers(question, {"new_experience_attributes" =>["1" => {start_year: 1990, end_year: 2000, company: "NewComp", job_title: "NewJob"}],
                                                "existing_experience_attributes" =>{exp1.id.to_s =>{company: "Chronus", start_year: 2003, end_year: 2004, job_title: "SDE"}}}, user, false, true)
    end

    ProfileAnswer.any_instance.expects(:build_new_experience_answers)
    member.update_experience_answers(question, {"new_experience_attributes" =>["1" => {start_year: 1991, end_year: 2000, company: "NewComp", job_title: "NewJob"}]}, user)
  end

  def test_update_experience_answers_no_new_and_existing_experience
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_experience_q)
    member.experiences.all.collect(&:destroy)
    exp1 = create_experience(member, question, start_year: 2000)
    exp2 = create_experience(member, question, start_year: 2001)
    assert_equal "SDE, MSFT\n SDE, MSFT", user.answer_for(question).answer_text

    assert_equal 2, member.reload.experiences.length
    member.update_experience_answers(question, {}, user)
    assert_equal 0, member.reload.experiences.length
    assert_nil user.answer_for(question)
  end

  def test_update_publication_answers_only_existing_publication
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_publication_q)
    member.publications.all.collect(&:destroy)
    pub1 = create_publication(member, question, day: 1, month: 1, year: 2010)
    pub2 = create_publication(member, question, day: 1, month: 1, year: 2012)
    assert_equal "Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication", user.answer_for(question).answer_text

    assert_equal 2, member.reload.publications.length
    member.update_publication_answers(question, {"existing_publication_attributes" =>{pub1.id.to_s =>{title: "Pub1", day: 1, month: 1, year: 2009}}}, user)
    assert_equal 1, member.reload.publications.length

    pub1.reload
    assert_equal "Pub1", pub1.title
    assert_equal 'January 01, 2009', pub1.formatted_date
    assert_equal "Pub1, Publisher ltd., http://public.url, Author, Very useful publication", user.answer_for(question).answer_text
  end

  def test_update_publication_answers_only_new_publication
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_publication_q)
    member.publications.all.collect(&:destroy)
    pub1 = create_publication(member, question, day: 1, month: 1, year: 2010)
    pub2 = create_publication(member, question, day: 1, month: 1, year: 2012)
    assert_equal "Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication", user.answer_for(question).answer_text

    assert_equal 2, member.reload.publications.length
    member.update_publication_answers(question, {"new_publication_attributes" =>["1" => {title: 'Pub1', day: 1, month: 1, year: 2010, authors: 'New author'}]}, user)
    assert_equal 1, member.reload.publications.length

    new_pub = member.publications.first
    assert_equal 'Pub1', new_pub.title
    assert_equal 'January 01, 2010', new_pub.formatted_date
    assert_equal "Pub1, , , New author, ", user.answer_for(question).answer_text
    # Update from basic info section
    member.update_publication_answers(question, {"new_publication_attributes" =>[{title: 'Basic', day: 1, month: 1, year: 2010, authors: 'New author'}]}, user)

    new_pub = member.reload.publications.first
    assert_equal 'Basic', new_pub.title
    assert_equal 'January 01, 2010', new_pub.formatted_date
    assert_equal "Basic, , , New author, ", user.answer_for(question).answer_text
  end

  def test_update_publication_answers_both_new_and_existing_publication
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_publication_q)
    member.publications.all.collect(&:destroy)
    pub1 = create_publication(member, question, day: 1, month: 1, year: 2010)
    pub2 = create_publication(member, question, day: 1, month: 1, year: 2012)
    assert_equal "Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication", user.answer_for(question).answer_text

    assert_equal 2, member.reload.publications.length
    member.update_publication_answers(question, {"new_publication_attributes" =>["1" => {title: 'Pub1', day: 1, month: 1, year: 2010, authors: 'New author'}], "existing_publication_attributes" =>{pub1.id.to_s =>{title: "Pub exist", day: 1, month: 1, year: 2009}}}, user)
    assert_equal 2, member.reload.publications.length
    new_pub = Publication.last
    pub1.reload
    assert_equal "Pub exist", pub1.title
    assert_equal 'January 01, 2009', pub1.formatted_date
    assert_equal 'Pub1', new_pub.title
    assert_equal 'January 01, 2010', new_pub.formatted_date
    assert_equal "Pub exist, Publisher ltd., http://public.url, Author, Very useful publication\n Pub1, , , New author, ", user.answer_for(question).answer_text
  end

  def test_update_publication_answers_no_new_and_existing_publication
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_publication_q)
    member.publications.all.collect(&:destroy)
    pub1 = create_publication(member, question, day: 1, month: 1, year: 2010)
    pub2 = create_publication(member, question, day: 1, month: 1, year: 2012)
    assert_equal "Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication", user.answer_for(question).answer_text

    assert_equal 2, member.reload.publications.length
    member.update_publication_answers(question, {}, user)
    assert_equal 0, member.reload.publications.length
    assert_nil user.answer_for(question)
  end

  def test_update_publication_answers_new_member_attribute
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:multi_publication_q)
    member.publications.all.collect(&:destroy)
    pub1 = create_publication(member, question, day: 1, month: 1, year: 2010)
    pub2 = create_publication(member, question, day: 1, month: 1, year: 2012)
    assert_equal "Publication, Publisher ltd., http://public.url, Author, Very useful publication\n Publication, Publisher ltd., http://public.url, Author, Very useful publication", user.answer_for(question).answer_text

    assert_equal 2, member.reload.publications.length
    member.update_publication_answers(question, {"new_publication_attributes" =>["1" => {title: 'Pub1', day: 1, month: 1, year: 2010, authors: 'New author'}]}, user)

    assert_equal 1, member.reload.publications.length
    assert_equal "Pub1, , , New author, ", user.answer_for(question).answer_text

    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Profile question has already been taken" do
      # here passing existing record as new and trying to create new experience answer
      member.update_publication_answers(question, {"new_publication_attributes" =>["1" => {title: 'Pub1', day: 1, month: 1, year: 2010, authors: 'New author'}],
                                                 "existing_publication_attributes" =>{pub1.id.to_s =>{title: "Pub exist", day: 1, month: 1, year: 2012}}}, user, false, true)
    end

    ProfileAnswer.any_instance.expects(:build_new_publication_answers)
    member.update_publication_answers(question, {"new_publication_attributes" =>["1" => {title: 'Pub2', day: 1, month: 1, year: 2010, authors: 'New author'}]}, user)
  end

  def test_update_manager_answers_only_existing_manager
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:manager_q)
    member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    manager = create_manager(member, question)
    assert_equal "Manager Name, manager@example.com", user.answer_for(question).answer_text

    member.update_manager_answers(question, {"existing_manager_attributes" =>{manager.id.to_s =>{first_name: "Man1", last_name: "Last1", email: "manager@example.com"}}}, user)

    manager.reload
    assert_equal "Man1", manager.first_name
    assert_equal "Last1", manager.last_name
    assert_equal "Man1 Last1, manager@example.com", user.answer_for(question).answer_text
  end

  def test_update_manager_answers_only_new_manager
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:manager_q)
    member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    manager = create_manager(member, question)
    assert_equal "Manager Name, manager@example.com", user.answer_for(question).answer_text

    member.update_manager_answers(question, {"new_manager_attributes" =>[{first_name: "Man1", last_name: "Last1", email: 'new_email@example.com'}]}, user)

    new_manager = Manager.last
    assert_equal "Man1", new_manager.first_name
    assert_equal "Last1", new_manager.last_name
    assert_equal "Man1 Last1, new_email@example.com", user.answer_for(question).answer_text
  end

  def test_update_manager_answers_no_new_and_existing_manager
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:manager_q)
    member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    manager = create_manager(member, question)
    assert_equal "Manager Name, manager@example.com", user.answer_for(question).answer_text
    member.update_manager_answers(question, {}, user)
    assert_nil user.answer_for(question)
  end

  def test_update_manager_answer_new_member_attribute
    user = users(:f_mentor)
    member = user.member
    question = profile_questions(:manager_q)
    member.profile_answers.includes(:profile_question).find{|a| a.profile_question.manager? }.manager.destroy
    manager = create_manager(member, question)
    assert_equal "Manager Name, manager@example.com", user.answer_for(question).answer_text

    ProfileAnswer.any_instance.expects(:build_new_manager_answers)
    assert_raise ActiveRecord::RecordInvalid, "Validation failed: Profile question has already been taken" do
      # here passing existing record as new and trying to create new education answer
      member.update_manager_answers(question, {"new_manager_attributes" =>[{first_name: "Man1", last_name: "Last1", email: 'new_email@example.com'}]}, user, false, true)
    end
  end


  def test_is_eligible_to_join_feature_eligibility_disabled
    #feature is not enabled/eligibility not enabled for role
    member = members(:f_mentor)
    program = programs(:albers)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    assert_false role.eligibility_rules
    assert_false program.membership_eligibility_rules_enabled?
    eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role])
    assert_false eligible_to_join_directly
    assert eligible_to_join
  end

  def test_is_eligible_to_join_feature_enabled_eligibility_disabled
    #feature is enabled/eligibility not enabled for role
    member = members(:f_mentor)
    program = programs(:albers)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    assert_false role.eligibility_rules
    assert program.membership_eligibility_rules_enabled?
    eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role])
    assert_false eligible_to_join_directly
    assert eligible_to_join
  end

  def test_is_eligible_to_join_feature_disabled_eligibility_enabled
    #feature is disabled/eligibility enabled for role
    member = members(:f_mentor)
    program = programs(:albers)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)

    program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, false)
    role.update_attribute(:eligibility_rules, true)
    assert role.eligibility_rules
    assert_false program.membership_eligibility_rules_enabled?
    eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role])
    assert_false eligible_to_join_directly
    assert eligible_to_join
  end

  def test_is_eligible_to_join_feature_eligibility_enabled_no_rule_set
    member = members(:f_mentor)
    program = programs(:albers)
    #feature enabled and eligibility enabled for role
    program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)

    assert program.membership_eligibility_rules_enabled?
    assert role.eligibility_rules
    eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role])
    assert eligible_to_join
    assert eligible_to_join_directly
  end

  def test_is_eligible_to_join_feature_eligibility_enabled_rule_set
    member = members(:f_mentor)
    program = programs(:albers)
    #feature enabled and eligibility enabled for role
    program.enable_feature(FeatureName::MEMBERSHIP_ELIGIBILITY_RULES, true)
    role = program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    role.update_attribute(:eligibility_rules, true)
    profile_question = program.organization.profile_questions.where(question_type: ProfileQuestion::Type::TEXT).last
    profile_answer = member.profile_answers.find_by(profile_question_id: profile_question.id)

    admin_view = AdminView.create!(program: member.organization, role_id: role.id, title: "New View", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {question_1: {question: "#{profile_question.id}", operator: AdminViewsHelper::QuestionType::ANSWERED.to_s, value: ""}}}, program_role_state: {AdminView::ProgramRoleStateFilterObjectKey::ALL_MEMBERS => true}
    }))
    assert_nil profile_answer

    assert program.membership_eligibility_rules_enabled?
    assert role.eligibility_rules
    eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role])
    assert_false eligible_to_join
    assert_false eligible_to_join_directly

    profile_answer = member.profile_answers.new(profile_question_id: profile_question.id)
    profile_answer.answer_text = "abc"
    profile_answer.save!
    member.reload
    eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role])
    assert eligible_to_join
    assert eligible_to_join_directly
  end

  def test_can_modify_eligibility_details
    member = members(:f_mentor)
    program = programs(:albers)
    organization = program.organization
    role1 = program.roles.find_by(name: "mentor")
    role2 = program.roles.find_by(name: "student")
    role3 = program.roles.find_by(name: "admin")
    prof_ques1 = organization.profile_questions.find_by(question_text: "Work")
    prof_ques2 = organization.profile_questions.find_by(question_text: "Education")
    prof_ques3 = organization.profile_questions.find_by(question_text: "Phone")

    admin_view1 = AdminView.create!(program: organization, role_id: role1.id, title: "New View1", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {
                      question_1: {question: prof_ques1.id, operator: AdminViewsHelper::QuestionType::ANSWERED.to_s, value: ""}
                     }},
    }))

    admin_view2 = AdminView.create!(program: organization, role_id: role2.id, title: "New View2", filter_params: AdminView.convert_to_yaml({
      profile: {questions: {
                    question_1: {question: prof_ques2.id, operator: AdminViewsHelper::QuestionType::ANSWERED.to_s, value: ""}
                  }}
    }))

    assert member.can_modify_eligibility_details?([])
    assert member.can_modify_eligibility_details?([role1, role2])
    prof_ques2.role_questions.where({role_id: role2.id}).first.update_attributes(admin_only_editable: true)
    prof_ques3.role_questions.where({role_id: role2.id}).first.update_attributes(admin_only_editable: true)
    assert member.can_modify_eligibility_details?([role1, role2])
    assert_false member.can_modify_eligibility_details?([role2])
  end

  def test_update_answers_for_multi_field_questions
    education_question = profile_questions(:multi_education_q)
    experience_question = profile_questions(:multi_experience_q)
    publication_question = profile_questions(:multi_publication_q)
    manager_question = profile_questions(:manager_q)

    member = members(:mentor_8)
    answer_map = {
      education_question.id => { "new_education_attributes" => [], "existing_education_attributes" => [] },
      experience_question.id => { "new_experience_attributes" => [], "existing_experience_attributes" => [] },
      publication_question.id => { "new_publication_attributes" => [], "existing_publication_attributes" => [] },
      manager_question.id => { "existing_manager_attributes" => [] }
    }

    member.expects(:update_education_answers).with(education_question, answer_map[education_question.id], nil, false, false).once
    member.expects(:update_experience_answers).with(experience_question, answer_map[experience_question.id], nil, false, false).once
    member.expects(:update_publication_answers).with(publication_question, answer_map[publication_question.id], nil, false, false).once
    member.expects(:update_manager_answers).with(manager_question, answer_map[manager_question.id], nil, false, false).once
    member.update_answers([education_question, experience_question, publication_question, manager_question], answer_map)

    membership_request = programs(:albers).membership_requests.new
    membership_request.role_names = [RoleConstants::MENTOR_NAME]
    member.expects(:update_education_answers).with(education_question, answer_map[education_question.id], membership_request, false, true).once
    member.expects(:update_experience_answers).with(experience_question, answer_map[experience_question.id], membership_request, false, true).once
    member.expects(:update_publication_answers).with(publication_question, answer_map[publication_question.id], membership_request, false, true).once
    member.expects(:update_manager_answers).with(manager_question, answer_map[manager_question.id], membership_request, false, true).once
    member.update_answers([education_question, experience_question, publication_question, manager_question], answer_map, membership_request, true)
  end

  def test_update_answers
    organization = programs(:org_primary)
    ordered_options_question = create_profile_question(question_type: ProfileQuestion::Type::ORDERED_OPTIONS, question_choices: ["A","B","C", "D", "E"], options_count: 3)
    profile_questions = organization.profile_questions
    string_question = profile_questions(:string_q)
    single_choice_question = profile_questions(:single_choice_q)
    multi_choice_question = profile_questions(:multi_choice_q)
    education_question = profile_questions(:multi_education_q)
    experience_question = profile_questions(:multi_experience_q)
    publication_question = profile_questions(:multi_publication_q)
    manager_question = profile_questions(:manager_q)
    location_question = profile_questions.where(question_type: ProfileQuestion::Type::LOCATION).first
    mandatory_child_question = create_question(program: single_choice_question.organization, question_type: ProfileQuestion::Type::SINGLE_CHOICE, role_names: [RoleConstants::MENTOR_NAME], conditional_question_id: single_choice_question.id, conditional_match_text: "opt_1", question_text: "conditional mandatory child question", question_choices: ["a", "b", "c"], required: true)
    mandatory_child_question.update_attributes!(section: single_choice_question.section)

    member = members(:mentor_8)
    assert member.profile_answers.empty?

    chennai_location = locations(:chennai)
    chennai_details = Geokit::GeoLoc.new(
        city: chennai_location.city,
        state_name: chennai_location.state,
        country_code: chennai_location.country,
        lat: chennai_location.lat,
        lng: chennai_location.lng,
        full_address: chennai_location.full_address)
    Location.stubs(:geocode).returns(chennai_details)

    answer_map = {
      string_question.id => "String Answer",
      single_choice_question.id => "opt_3",
      mandatory_child_question.id => nil,
      multi_choice_question.id => "Stand, Run",
      ordered_options_question.id => "A, C",
      education_question.id => { "new_education_attributes" => [ { "0" => { "school_name" => "CEG", "degree" => "BE", "major" => "CSE", "graduation_year" => "2013" },
        "1" => { "school_name" => "MIT", "degree" => "ME", "major" => "IT", "graduation_year" => "2015" } } ] },
      experience_question.id => { "new_experience_attributes" => [ { "0" => { "job_title" => "SDE", "company" => "Chronus", "start_month" => "7", "start_year" => "2013", "current_job" => "true" } } ] },
      publication_question.id => { "new_publication_attributes" => [ { "0" => { "title" => "Article 23", "publisher" => "Pearson", "authors" => "AUTHOR", "url" => "www.chronus.com", "day" => "8", "month" => "3", "year" => "2016" } } ] },
      manager_question.id => { "new_manager_attributes" => [ { "first_name" => "Manager", "last_name" => "Name", "email" => "manager.name@chronus.com" } ] },
      location_question.id => "Chennai, Tamil Nadu, India",
    }

    assert_difference "ProfileAnswer.count", 9 do
      assert_difference "Education.count", 2 do
        assert_difference "Experience.count", 1 do
          assert_difference "Publication.count", 1 do
            assert_difference "Manager.count", 1 do
              assert_no_difference "Location.count" do
                assert member.update_answers(profile_questions, answer_map.with_indifferent_access, nil, false, false, from_import: true)
              end
            end
          end
        end
      end
    end
    question_id_answer_map = member.profile_answers.index_by(&:profile_question_id)
    educations = question_id_answer_map[education_question.id].educations
    experience = question_id_answer_map[experience_question.id].experiences[0]
    publication = question_id_answer_map[publication_question.id].publications[0]
    assert_equal "String Answer", question_id_answer_map[string_question.id].answer_value
    assert_equal "opt_3", question_id_answer_map[single_choice_question.id].answer_value
    assert_equal ["Stand", "Run"], question_id_answer_map[multi_choice_question.id].answer_value
    assert_equal ["A", "C"], question_id_answer_map[ordered_options_question.id].answer_value
    assert_equal_unordered [["CEG", "BE", "CSE"], ["MIT", "ME", "IT"]], question_id_answer_map[education_question.id].answer_value
    assert_equal_unordered [2013, 2015], educations.pluck(:graduation_year)
    assert_equal [["SDE", "Chronus"]], question_id_answer_map[experience_question.id].answer_value
    assert_equal "7 2013", "#{experience.start_month} #{experience.start_year}"
    assert experience.current_job
    assert_equal [["Article 23", "Pearson", "http://www.chronus.com", "AUTHOR"]], question_id_answer_map[publication_question.id].answer_value
    assert_equal "8 3 2016", "#{publication.day} #{publication.month} #{publication.year}"
    assert_equal [["Manager Name", "manager.name@chronus.com"]], question_id_answer_map[manager_question.id].answer_value
    assert_equal "Chennai, Tamil Nadu, India", question_id_answer_map[location_question.id].answer_value
    assert_equal chennai_location, question_id_answer_map[location_question.id].location

    answer_map[single_choice_question.id] = "opt_1"
    assert_false member.update_answers(profile_questions, answer_map.with_indifferent_access, nil, false)
  end

  def test_update_answers_for_file_type_question
    member = members(:mentor_8)
    assert member.profile_answers.empty?
    file_question = profile_questions(:mentor_file_upload_q)
    file = fixture_file_upload(File.join('files', 'some_file.txt'), 'text/text')

    file_uploader = FileUploader.new(file_question.id, "new", file, base_path: ProfileAnswer::TEMP_BASE_PATH)
    file_uploader.save
    FileUploader.expects(:get_file_path).with(file_question.id, 'new', ProfileAnswer::TEMP_BASE_PATH, { code: file_uploader.uniq_code, file_name: "some_file.txt" }).returns(file)
    ProfileAnswer.any_instance.expects(:assign_file_name_and_code).with("some_file.txt", file_uploader.uniq_code)
    params = { "question_#{file_question.id}_code" => file_uploader.uniq_code }
    assert_difference "ProfileAnswer.count", 1 do
      member.update_answers([file_question], { file_question.id => "some_file.txt" }, nil, true, false, params)
    end
    answer = ProfileAnswer.last
    assert_match /some_file.txt/, answer.attachment_file_name

    file = fixture_file_upload(File.join('files', 'test_file.css'), 'text/css')
    file_uploader = FileUploader.new(file_question.id, member.id, file, base_path: ProfileAnswer::TEMP_BASE_PATH)
    file_uploader.save
    FileUploader.expects(:get_file_path).with(file_question.id, member.id, ProfileAnswer::TEMP_BASE_PATH, { code: file_uploader.uniq_code, file_name: "test_file.css" }).returns(file)
    ProfileAnswer.any_instance.expects(:assign_file_name_and_code).with("test_file.css", file_uploader.uniq_code)
    params = { "question_#{file_question.id}_code" => file_uploader.uniq_code, "persisted_files" => { file_question.id => "0" } }
    assert_no_difference "ProfileAnswer.count" do
      member.update_answers([file_question], { file_question.id => "test_file.css" }, nil, false, false, params)
    end
    assert_match /test_file.css/, answer.reload.attachment_file_name

    FileUploader.expects(:get_file_path).with(file_question.id, member.id, ProfileAnswer::TEMP_BASE_PATH, {:code => 'empty', :file_name => ''})

    params = { "persisted_files" => { file_question.id => "0" } }
    assert_difference "ProfileAnswer.count", -1 do
      member.update_answers([file_question], { file_question.id => "" }, nil, false, false, params)
    end
    assert_raise(ActiveRecord::RecordNotFound) { answer.reload }
  end

  def test_update_answers_invalid
    member = members(:mentor_8)
    assert member.profile_answers.empty?
    single_choice_question = profile_questions(:single_choice_q)
    assert_equal ["opt_1", "opt_2", "opt_3"], single_choice_question.default_choices
    assert_false single_choice_question.allow_other_option?

    assert_no_difference "ProfileAnswer.count" do
      assert_false member.update_answers([single_choice_question], { single_choice_question.id => "invalid_option" }.with_indifferent_access)
    end
  end

  def test_active_programs_associations
    member = members(:nch_admin)
    assert_equal [programs(:primary_portal), programs(:nch_mentoring)], member.active_programs
    assert_equal [programs(:nch_mentoring)], member.active_tracks
    assert_equal [programs(:primary_portal)], member.active_portals
    User.any_instance.expects(:close_pending_received_requests_and_offers).twice
    users(:portal_admin).suspend_from_program!(users(:subportal_admin), "No Reason")
    users(:nch_admin).suspend_from_program!(users(:nch_admin), "Hmm, I can suspend myself")
    member.reload
    assert_equal [], member.active_tracks
    assert_equal [], member.active_portals
  end

  def test_transition_global_suspensions_to_program
    admin_member = members(:f_admin)
    member = members(:f_mentor)
    user = users(:f_mentor)
    member_2 = members(:f_student)
    user_2 = users(:f_student)
    assert member.active? && member_2.active?
    assert user.active? && user_2.active?

    member.suspend!(admin_member, "")
    suspend_user(user_2)
    member_2.suspend!(admin_member, "")
    assert member.suspended? && member_2.suspended?
    assert user.reload.suspended? && user_2.reload.suspended?
    assert_equal User::Status::ACTIVE, user.global_reactivation_state
    assert_nil user.track_reactivation_state
    assert_equal User::Status::ACTIVE, user_2.track_reactivation_state
    assert_equal User::Status::SUSPENDED, user_2.global_reactivation_state

    Member.transition_global_suspensions_to_program([member.id, member_2.id])
    assert member.reload.active? && member_2.reload.active?
    assert user.reload.suspended? && user_2.reload.suspended?
    assert user.global_reactivation_state.nil? && user_2.global_reactivation_state.nil?
    assert_equal User::Status::ACTIVE, user.track_reactivation_state
    assert_equal User::Status::ACTIVE, user_2.track_reactivation_state
  end

  def test_can_show_browser_warning
    admin_member = members(:f_admin)
    assert_nil admin_member.browser_warning_shown_at
    assert admin_member.can_show_browser_warning?

    admin_member.update_attributes!(browser_warning_shown_at: Time.now - 2.days)
    assert_false admin_member.reload.can_show_browser_warning?

    admin_member.update_attributes!(browser_warning_shown_at: Time.now - 4.days)
    assert admin_member.reload.can_show_browser_warning?
  end

  def test_accepted_meetings
    member = members(:f_mentor)
    meetings = [meetings(:f_mentor_mkr_student_daily_meeting), meetings(:f_mentor_mkr_student), meetings(:upcoming_calendar_meeting)]
    assert_equal_unordered meetings, member.accepted_meetings
    member.member_meetings.where(meeting_id: meetings(:f_mentor_mkr_student).id).first.update_attribute(:attending, MemberMeeting::ATTENDING::NO)
    member.reload
    assert_equal_unordered [meetings(:f_mentor_mkr_student_daily_meeting), meetings(:upcoming_calendar_meeting)], member.accepted_meetings
  end

  def test_accepted_flash_meetings
    assert_equal [], members(:f_admin).accepted_flash_meetings
    member = members(:f_mentor)
    assert_equal [meetings(:upcoming_calendar_meeting)], member.accepted_flash_meetings
    member.member_meetings.where(meeting_id: meetings(:upcoming_calendar_meeting).id).first.update_attribute(:attending, MemberMeeting::ATTENDING::NO)
    member.reload
    assert_equal [], member.accepted_flash_meetings
  end

  def test_set_mobile_access_tokens_v2
    member = members(:f_student)
    assert_equal [], member.mobile_devices

    assert_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("Skyler!!", "test", MobileDevice::Platform::IOS)
    end

    assert_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("Alicia Florick!!", "test1", MobileDevice::Platform::IOS)
    end

    assert_equal ["Skyler!!", "Alicia Florick!!"], member.reload.mobile_devices.collect(&:device_token)

    # Same device token already present
    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("Alicia Florick!!", "test1", MobileDevice::Platform::IOS)
    end
    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("Skyler!!", "test", MobileDevice::Platform::IOS)
    end

    # Same device token but different platform, should create new device
    assert_difference "MobileDevice.count", 1 do
      member.set_mobile_access_tokens_v2!("Alicia Florick!!", "test1", MobileDevice::Platform::ANDROID)
    end
    assert_difference "MobileDevice.count", 1 do
      member.set_mobile_access_tokens_v2!("Skyler!!", "test", MobileDevice::Platform::ANDROID)
    end

    # blank case
    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("", "test", MobileDevice::Platform::IOS)
    end
    # blank case
    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("Skyler!!", nil, MobileDevice::Platform::IOS)
    end

    # blank case
    assert_no_difference "MobileDevice.count" do
      member.set_mobile_access_tokens_v2!("Skyler!!", nil, "")
    end

    assert_difference "MobileDevice.count", -1 do
      member.set_mobile_access_tokens_v2!("Skyler!!", "test1", MobileDevice::Platform::IOS)
    end
    assert_equal ["Skyler!!"], member.reload.mobile_devices.ios_devices.collect(&:device_token)
    assert_equal ["Alicia Florick!!", "Skyler!!"], member.reload.mobile_devices.android_devices.collect(&:device_token)
  end

  def test_sign_out_of_other_sessions
    member = members(:f_student)

    ["session_id_1", "session_id_2"].each do |session_id|
      ActiveRecord::SessionStore::Session.create!(session_id: session_id, data: {"member_id" => member.id})
    end

    member.sign_out_of_other_sessions("session_id_1", false, false)
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).first.session_id, "session_id_1"
    assert_nil member.remember_token
    assert_equal member.mobile_devices.count, 0

    member.remember_me
    member.sign_out_of_other_sessions("session_id_1", member.remember_token, false)
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_not_nil member.remember_token
    assert_equal member.mobile_devices.count, 0

    member.sign_out_of_other_sessions("session_id_1", "different_current_remember_me_cookie", false)
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_nil member.remember_token
    assert_equal member.mobile_devices.count, 0

    member.remember_me
    member.sign_out_of_other_sessions("session_id_1", nil, false)
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_nil member.remember_token
    assert_equal member.mobile_devices.count, 0

    mobile_devices = []
    mobile_devices << member.set_mobile_access_tokens_v2!("Iphone", "qwerty", MobileDevice::Platform::IOS)
    mobile_devices << member.set_mobile_access_tokens_v2!("HTC", "asdfgh", MobileDevice::Platform::IOS)
    assert_equal_unordered member.mobile_devices.pluck(:id), mobile_devices.collect(&:id)

    member.sign_out_of_other_sessions("session_id_1", nil, "qwerty")
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_nil member.remember_token
    assert_equal member.mobile_devices.count, 1
    assert_equal member.mobile_devices.first.mobile_auth_token, "qwerty"

    member.sign_out_of_other_sessions("session_id_1", nil, false)
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 1
    assert_nil member.remember_token
    assert_equal member.mobile_devices.count, 0

    member.sign_out_of_other_sessions("some_other_session_id", nil, false)
    member.reload
    assert_equal ActiveRecord::SessionStore::Session.where(member_id: member.id).count, 0
    assert_nil member.remember_token
    assert_equal member.mobile_devices.count, 0
  end

  def test_scrap_inbox_unread_count
    group = groups(:mygroup)
    group1 = create_group(students: users(:rahim), mentor: users(:f_mentor), program: programs(:albers))
    member = members(:f_mentor)
    assert_equal 2, member.reload.scrap_inbox_unread_count(group.reload)

    create_message(sender: members(:rahim), receiver: member)
    assert_equal 2, member.reload.scrap_inbox_unread_count(group.reload)

    create_scrap(sender: members(:rahim), group: group1)
    assert_equal 2, member.reload.scrap_inbox_unread_count(group.reload)

    scrap = create_scrap(sender: members(:mkr_student), group: group)
    assert_equal 3, member.reload.scrap_inbox_unread_count(group.reload)

    create_scrap(sender: member, group: group)
    assert_equal 3, member.reload.scrap_inbox_unread_count(group.reload)

    scrap.root.mark_tree_as_read!(member)
    assert_equal 2, member.reload.scrap_inbox_unread_count(group.reload)

    scrap = create_scrap(sender: members(:mkr_student), group: group)
    assert_equal 3, member.reload.scrap_inbox_unread_count(group.reload)

    scrap.mark_deleted!(member)
    assert_equal 2, member.reload.scrap_inbox_unread_count(group.reload)
  end

  def test_get_attending_and_not_responded_meetings
    group = groups(:mygroup)
    recurrent_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    non_recurrent_meeting = meetings(:f_mentor_mkr_student)
    non_recurrent_meeting_hash = [{ current_occurrence_time: non_recurrent_meeting.start_time, meeting: non_recurrent_meeting }]
    first_occurrence = Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time]
    recurrent_meeting_hash = { current_occurrence_time: first_occurrence, meeting: recurrent_meeting }
    member1 = members(:mkr_student)
    assert_equal non_recurrent_meeting_hash, member1.get_attending_and_not_responded_meetings([{ current_occurrence_time: non_recurrent_meeting.start_time, meeting: non_recurrent_meeting.reload }])
    member1.mark_attending!(non_recurrent_meeting, attending: MemberMeeting::ATTENDING::NO_RESPONSE)
    assert_equal non_recurrent_meeting_hash, member1.get_attending_and_not_responded_meetings([{ current_occurrence_time: non_recurrent_meeting.start_time, meeting: non_recurrent_meeting.reload }])
    member1.mark_attending!(non_recurrent_meeting, attending: MemberMeeting::ATTENDING::NO)
    assert_equal [], member1.get_attending_and_not_responded_meetings([{ current_occurrence_time: non_recurrent_meeting.start_time, meeting: non_recurrent_meeting.reload }])
    assert_equal Meeting.upcoming_recurrent_meetings([recurrent_meeting]), member1.get_attending_and_not_responded_meetings(Meeting.upcoming_recurrent_meetings([recurrent_meeting]))
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, first_occurrence)
    assert_equal Meeting.upcoming_recurrent_meetings([recurrent_meeting]), member1.get_attending_and_not_responded_meetings(Meeting.upcoming_recurrent_meetings([recurrent_meeting.reload]))
    attending_not_responsed_meetings_count = member1.get_attending_and_not_responded_meetings(Meeting.upcoming_recurrent_meetings([recurrent_meeting.reload])).count
    assert member1.get_attending_and_not_responded_meetings(Meeting.upcoming_recurrent_meetings([recurrent_meeting.reload])).include?(recurrent_meeting_hash)
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO, first_occurrence)
    assert_equal (attending_not_responsed_meetings_count - 1), member1.get_attending_and_not_responded_meetings(Meeting.upcoming_recurrent_meetings([recurrent_meeting.reload])).count
    assert_false member1.get_attending_and_not_responded_meetings(Meeting.upcoming_recurrent_meetings([recurrent_meeting.reload])).include?(recurrent_meeting_hash)
  end

  def test_get_upcoming_not_responded_meetings_count_in_groups
    group = groups(:mygroup)
    member1 = members(:mkr_student)
    member2 = members(:f_mentor)
    recurrent_meeting = meetings(:f_mentor_mkr_student_daily_meeting)

    upcoming_not_responsed_meetings_count = member1.get_upcoming_not_responded_meetings_count(group.program, group)
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO, Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time])
    assert_equal (upcoming_not_responsed_meetings_count - 1), member1.get_upcoming_not_responded_meetings_count(group.program, group)
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time])
    assert_equal upcoming_not_responsed_meetings_count, member1.get_upcoming_not_responded_meetings_count(group.program, group)
    #past meeting
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, recurrent_meeting.occurrences.first.start_time)
    #no change
    assert_equal upcoming_not_responsed_meetings_count, member1.get_upcoming_not_responded_meetings_count(group.program, group)
    member2.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time])
    assert_equal upcoming_not_responsed_meetings_count, member1.get_upcoming_not_responded_meetings_count(group.program, group)
    assert_equal 1, member2.get_upcoming_not_responded_meetings_count(group.program, group)
  end

  def test_get_upcoming_not_responded_meetings_count_without_group
    program = programs(:albers)
    member1 = members(:mkr_student)
    member2 = members(:f_mentor)

    program.enable_feature(FeatureName::CALENDAR, true)
    program.enable_feature(FeatureName::MENTORING_CONNECTION_MEETING, true)

    recurrent_meeting = meetings(:f_mentor_mkr_student_daily_meeting)
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_meeting_time(meeting.start_time + 3.days, meeting.schedule.duration + 30.minutes, updated_by_member: meeting.owner)
    meeting.member_meetings.update_all(attending: MemberMeeting::ATTENDING::NO_RESPONSE)

    meeting.update_attribute(:mentee_id, members(:mkr_student).id)
    meeting.update_attribute(:group_id, nil)

    upcoming_not_responsed_meetings_count = member1.get_upcoming_not_responded_meetings_count(program)
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO, Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time])
    assert_equal (upcoming_not_responsed_meetings_count - 1), member1.get_upcoming_not_responded_meetings_count(program)
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time])
    assert_equal upcoming_not_responsed_meetings_count, member1.get_upcoming_not_responded_meetings_count(program)
    #past meeting
    member1.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, recurrent_meeting.occurrences.first.start_time)
    #no change
    assert_equal upcoming_not_responsed_meetings_count, member1.get_upcoming_not_responded_meetings_count(program)
    member2.mark_attending_for_an_occurrence!(recurrent_meeting, MemberMeeting::ATTENDING::NO_RESPONSE, Meeting.upcoming_recurrent_meetings([recurrent_meeting]).first[:current_occurrence_time])
    assert_equal upcoming_not_responsed_meetings_count, member1.get_upcoming_not_responded_meetings_count(program)

    assert_equal 2, member2.get_upcoming_not_responded_meetings_count(program)

    meeting.member_meetings.update_all(attending: MemberMeeting::ATTENDING::NO)

    assert_equal (upcoming_not_responsed_meetings_count - 1), member1.get_upcoming_not_responded_meetings_count(program)
    assert_equal 1, member2.get_upcoming_not_responded_meetings_count(program)
  end

  def test_has_many_user_activities
    assert 0, members(:f_admin).user_activities.count
    UserActivity.create!(member_id: members(:f_admin))
    assert 1, members(:f_admin).user_activities.count
  end

  def test_has_upcoming_meeting_with
    mentor = members(:f_mentor)
    mentee = members(:mkr_student)
    mentee_1 = members(:student_2)
    mentor_1 = members(:mentor_0)
    time = 2.days.from_now
    assert mentor.has_upcoming_meeting_with?(mentee)
    assert_false mentor_1.has_upcoming_meeting_with?(mentee_1)

    #flash upcoming accepted meeting with different attending response
    m = create_meeting(owner_id: mentor_1.id, members: [mentor_1, mentee_1], force_non_time_meeting: true, force_non_group_meeting: true, start_time: time, end_time: time + 30.minutes, requesting_student: users(:student_2), requesting_mentor: users(:mentor_0))
    m.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m.reload
    assert mentor_1.has_upcoming_meeting_with?(mentee_1)
    m.member_meetings.first.update_attributes(attending: MemberMeeting::ATTENDING::NO)
    m.reload
    assert_false mentor_1.has_upcoming_meeting_with?(mentee_1)
    m.destroy

    #past accepted meeting and attending or no response
    m = create_meeting(owner_id: mentor_1.id, members: [mentor_1, mentee_1], force_non_time_meeting: true, force_non_group_meeting: true, start_time: 2.days.ago, end_time: 2.days.ago + 30.minutes, requesting_student: users(:student_2), requesting_mentor: users(:mentor_0))
    m.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m.reload
    m.meeting_request.update_attributes(status: AbstractRequest::Status::ACCEPTED)
    m.reload
    assert_false mentor_1.has_upcoming_meeting_with?(mentee_1)
    m.destroy

    # recurrent meeting with different attending
    g = create_group(:students => users(:student_2), :mentor => users(:mentor_0), :program => programs(:albers))
    m = create_meeting(owner_id: mentor_1.id, members: [mentor_1, mentee_1], force_non_time_meeting: true, start_time: time, end_time: time + 30.minutes, requesting_student: users(:student_2), requesting_mentor: users(:mentor_0), group_id: g.id)
    assert mentor_1.has_upcoming_meeting_with?(mentee_1)
    m.member_meetings.first.update_attributes(attending: MemberMeeting::ATTENDING::NO)
    assert_false mentor_1.has_upcoming_meeting_with?(mentee_1)
    m.destroy
  end

  def test_get_active_or_closed_groups_count
    member = members(:f_mentor)
    assert_equal member.get_active_or_closed_groups_count(Group::Status::ACTIVE_CRITERIA), 3
    
    group = groups(:mygroup)
    group.terminate!(users(:f_admin), "Test reason", group.program.permitted_closure_reasons.first.id)
    assert_equal member.reload.get_active_or_closed_groups_count(Group::Status::CLOSED), 1
  end

  def test_closed_engagements_count
    member = members(:f_mentor)
    assert_equal 0, member.closed_engagements_count

    group = groups(:mygroup)
    group.terminate!(users(:f_admin), "Test reason", group.program.permitted_closure_reasons.first.id)
    assert_equal 1, member.reload.closed_engagements_count
  end

  def test_ongoing_engagements_count
    member = members(:f_mentor)
    assert_equal 3, member.ongoing_engagements_count

    member = members(:f_student)
    assert_equal 2, member.ongoing_engagements_count
  end

  def test_total_engagements_count
    member = members(:f_mentor)
    assert_equal 3, member.total_engagements_count

    member = members(:f_student)
    assert_equal 2, member.total_engagements_count
  end

  def test_get_busy_slots_for_members
    Timecop.freeze
    member = members(:f_mentor)
    stub_busy_slots_for_members([member.id])
    result = Member.get_busy_slots_for_members(Date.current.beginning_of_day, Date.tomorrow.beginning_of_day, members: [member])
    assert_equal 3, result.size
    assert_equal ({title: "Busy - Good unique name", className: "non_self_meetings", clickable: false, editable: false}), result.first.slice(:title, :className, :clickable, :editable)
    Timecop.return
  end

  def test_get_busy_slot_events
    Timecop.freeze
    member = members(:f_mentor)
    stub_busy_slots_for_members([member.id])
    busy_time = CalendarQuery.get_busy_slots_for_members(Date.current.beginning_of_day, Date.tomorrow.beginning_of_day, members: [member])
    result = Member.get_busy_slot_events(member, busy_time[member.id][:busy_slots])
    assert_equal 3, result.size
    assert_equal ({title: "Busy - Good unique name", className: "non_self_meetings", clickable: false, editable: false}), result.first.slice(:title, :className, :clickable, :editable)
    Timecop.return
  end

  def test_get_busy_slot_events_timezone
    Timecop.freeze
    member = members(:f_mentor)
    student = members(:f_student)
    stub_busy_slots_for_members([member.id])
    busy_time = CalendarQuery.get_busy_slots_for_members(Date.current.beginning_of_day, Date.tomorrow.beginning_of_day, members: [member])
    first_start_time = busy_time[member.id][:busy_slots].first[:start_time]

    result = Member.get_busy_slot_events(member, busy_time[member.id][:busy_slots])
    assert_equal TimezoneConstants::DEFAULT_TIMEZONE, member.get_valid_time_zone 
    assert_equal DateTime.localize(first_start_time.in_time_zone(member.get_valid_time_zone), format: :full_date_full_time_cal_sync), result.first[:start]

    member.time_zone = "Asia/Kolkata"
    result = Member.get_busy_slot_events(member, busy_time[member.id][:busy_slots])
    assert_equal "Asia/Kolkata", member.get_valid_time_zone 
    assert_equal DateTime.localize(first_start_time.in_time_zone(member.get_valid_time_zone), format: :full_date_full_time_cal_sync), result.first[:start]

    student.time_zone = "America/Los_Angeles"
    result = Member.get_busy_slot_events(member, busy_time[member.id][:busy_slots], viewing_member: student)
    assert_equal "America/Los_Angeles", student.get_valid_time_zone 
    assert_equal DateTime.localize(first_start_time.in_time_zone(student.get_valid_time_zone), format: :full_date_full_time_cal_sync), result.first[:start]
    Timecop.return
  end

  def test_synced_external_calendar?
    member = members(:f_mentor)
    assert_false member.synced_external_calendar?

    member.o_auth_credentials.new
    assert member.synced_external_calendar?

    member.o_auth_credentials.new
    assert member.synced_external_calendar?
    assert_equal 2, member.o_auth_credentials.size    
  end

  def test_get_organization_wide_calendar_access_for
    program = programs(:org_primary)
    assert_false Member.get_organization_wide_calendar_access_for(program)
    program.enable_feature(FeatureName::ORG_WIDE_CALENDAR_ACCESS)
    assert Member.get_organization_wide_calendar_access_for(program)
    assert_false Member.get_organization_wide_calendar_access_for(nil)
  end

  def test_show_one_time_settings
    member = members(:f_mentor)
    program = member.programs.first

    assert_false program.calendar_sync_v2_enabled?
    assert member.show_one_time_settings?(program)

    program.enable_feature(FeatureName::CALENDAR_SYNC_V2)

    assert program.calendar_sync_v2_enabled?
    assert_false member.synced_external_calendar?
    assert member.show_one_time_settings?(program)

    member.stubs(:synced_external_calendar?).returns(true)
    assert program.calendar_sync_v2_enabled?
    assert member.synced_external_calendar?
    assert_false member.show_one_time_settings?(program)
  end

  def test_password_required
    member = members(:f_mentor)
    assert_false member.password_required?

    member.validate_password = true
    assert member.password_required?

    member.validate_password = nil
    member.password = ""
    assert member.password_required?
  end

  def test_allow_password_update
    member = members(:f_mentor)
    chronus_auth = member.organization.chronus_auth
    assert member.allow_password_update?

    member.crypted_password = nil
    assert_false member.allow_password_update?

    chronus_auth.disable!
    assert_false member.reload.allow_password_update?
  end

  def test_login_identifers_for_custom_auths
    member = members(:f_student)
    organization = member.organization
    custom_auth_1 = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    custom_auth_2 = organization.auth_configs.create!(auth_type: AuthConfig::Type::SOAP)
    login_identifier_1 = member.login_identifiers.create!(auth_config_id: custom_auth_1.id, identifier: "uid")
    assert_equal [login_identifier_1], member.login_identifiers_for_custom_auths

    assert_no_difference "member.login_identifiers.count" do
      member.build_login_identifiers_for_custom_auths("")
    end
    assert_equal "uid", login_identifier_1.reload.identifier

    assert_difference "member.login_identifiers.count" do
      member.build_login_identifiers_for_custom_auths("revised_uid")
      member.save!
    end
    login_identifier_2 = member.login_identifiers.find_by(auth_config_id: custom_auth_2.id)
    assert_equal "revised_uid", login_identifier_1.reload.identifier
    assert_equal "revised_uid", login_identifier_2.identifier
    assert_equal_unordered [login_identifier_1, login_identifier_2], member.login_identifiers_for_custom_auths
  end

  def test_activate_from_dormant
    member = members(:dormant_member)
    initial_created_at = member.created_at

    member.activate_from_dormant
    Timecop.freeze(Time.now.change(usec: 0)) do
      assert_equal Member::Status::ACTIVE, member.state
      assert_equal Time.now, member.created_at
    end
    member.reload
    assert_equal Member::Status::DORMANT, member.state
    assert_equal initial_created_at, member.created_at
  end

  def test_meeting_larger_than_slot
    time = Time.new(2018, 1, 1).utc
    meeting = { start_time: time, end_time: time + 4.hours }
    slot_hash = { start: time + 1.hour, end: time + 2.hours }
    assert Member.meeting_larger_than_slot?(meeting, slot_hash)

    meeting = { start_time: time, end_time: time + 4.hours }
    slot_hash = { start: time + 5.hour, end: time + 6.hours }
    assert_false Member.meeting_larger_than_slot?(meeting, slot_hash)
  end

  def test_meeting_left_overlap_slot
    time = Time.new(2018, 1, 1).utc
    meeting = { start_time: time  + 1.hour, end_time: time + 3.hours }
    slot_hash = { start: time + 2.hours, end: time + 4.hours }
    slot = slot_hash.clone
    Member.meeting_left_overlap_slot(meeting, slot_hash, slot)
    assert_equal_hash({ start: time + 3.hours, end: time + 4.hours }, slot)
  end

  def test_meeting_right_overlap_slot
    time = Time.new(2018, 1, 1).utc
    meeting = { start_time: time + 2.hours, end_time: time + 4.hours }
    slot_hash = { start: time + 1.hour, end: time + 3.hours }
    slot = slot_hash.clone
    Member.meeting_right_overlap_slot(meeting, slot_hash, slot)
    assert_equal_hash({ start: time + 1.hour, end: time + 2.hours }, slot)
  end

  def test_meeting_smaller_inside_slot
    time = Time.new(2018, 1, 1).utc
    meeting = { start_time: time + 2.hours, end_time: time + 3.hours }
    slot_hash = { start: time  + 1.hour, end: time + 4.hours }
    slot = slot_hash.clone
    mentoring_slots = []
    Member.meeting_smaller_inside_slot(meeting, slot_hash, slot, mentoring_slots)
    assert_equal_hash({ start: time + 3.hours, end: time + 4.hours }, slot)
    assert_equal [{ start: time + 1.hour, end: time + 2.hours }], mentoring_slots

    meeting = { start_time: time + 2.hours, end_time: time + 4.hours }
    slot_hash = { start: time  + 1.hour, end: time + 4.hours }
    slot = slot_hash.clone
    mentoring_slots = []
    Member.meeting_smaller_inside_slot(meeting, slot_hash, slot, mentoring_slots)
    assert_equal_hash({ start: time + 1.hour, end: time + 2.hours }, slot)
    assert_equal [], mentoring_slots

    meeting = { start_time: time + 1.hour, end_time: time + 2.hours }
    slot_hash = { start: time  + 1.hour, end: time + 4.hours }
    slot = slot_hash.clone
    mentoring_slots = []
    Member.meeting_smaller_inside_slot(meeting, slot_hash, slot, mentoring_slots)
    assert_equal_hash({ start: time + 2.hours, end: time + 4.hours }, slot)
    assert_equal [], mentoring_slots
  end

  def test_merge_busy_slots
    assert_empty Member.merge_busy_slots([], false)

    time = Time.new(2018, 1, 1).utc
    slots = []
    slots << { start_time: time, end_time: time + 4.hours }
    slots << { start_time: time + 1.hour, end_time: time + 2.hours }
    assert_equal [{ start_time: time, end_time: time + 4.hours }], Member.merge_busy_slots(slots)

    slots = []
    slots << { start_time: time + 1.hour, end_time: time + 3.hours }
    slots << { start_time: time + 2.hours, end_time: time + 4.hours }
    assert_equal [{ start_time: time + 1.hour, end_time: time + 4.hours }], Member.merge_busy_slots(slots)

    slots=[]
    slots << { start_time: time + 2.hours, end_time: time + 4.hours }
    slots << { start_time: time + 1.hour, end_time: time + 3.hours }
    assert_equal [{ start_time: time + 1.hour, end_time: time + 4.hours }], Member.merge_busy_slots(slots)

    slots=[]
    slots << { start_time: time + 5.hours, end_time: time + 6.hours }
    slots << { start_time: time + 2.hours, end_time: time + 4.hours }
    assert_equal slots.reverse, Member.merge_busy_slots(slots)

    slots=[]
    slots << { start_time: time + 2.hours, end_time: time + 4.hours }
    slots << { start_time: time + 4.hours, end_time: time + 6.hours }
    assert_equal [{ start_time: time + 2.hours, end_time: time + 6.hours }], Member.merge_busy_slots(slots)

    slots=[]
    slots << { start_time: time + 2.hours, end_time: time + 4.hours }
    slots << { start_time: time + 2.hours, end_time: time + 4.hours }
    assert_equal [{ start_time: time + 2.hours, end_time: time + 4.hours }], Member.merge_busy_slots(slots)
  end

  def test_add_mandatory_slot_to_free_slots
    time = Time.new(2018, 1, 1).utc
    options = {}
    free_slots = []
    free_slots << { start: time + 1.hour, end: time + 3.hours }
    free_slots << { start: time + 4.hours, end: time + 6.hours }
    assert_equal free_slots, Member.add_mandatory_slot_to_free_slots(free_slots, options)

    options[:mandatory_times] = [{ start: time + 3.hours, end: time + 5.hours }]
    assert_equal [{ start: time + 1.hour, end: time + 6.hours }], Member.add_mandatory_slot_to_free_slots(free_slots, options)
  end

  def test_get_chronus_calendar_meeting_slots
    current_time = Time.new(2018, 3, 1)
    members = [members(:f_mentor), members(:f_student)]
    meeting = meetings(:f_mentor_mkr_student)
    meeting.update_attributes(start_time: current_time + 2.hours, end_time: current_time + 2.hours + 30.minutes)
    Member.any_instance.stubs(:get_attending_or_unanswred_recurrent_meetings_within_time).returns([{current_occurrence_time: current_time + 2.hours, meeting: meeting}])
    assert_equal [], Member.get_chronus_calendar_meeting_slots(current_time, current_time + 1.day)
    assert_equal [{start_time: current_time.utc + 2.hours, end_time: current_time.utc + 2.hours + 30.minutes}, {start_time: current_time.utc + 2.hours, end_time: current_time.utc + 2.hours + 30.minutes}], Member.get_chronus_calendar_meeting_slots(current_time, current_time + 1.day, {members: members})
  end

  def test_get_members_free_slots_after_meetings
    time = Time.new(2018, 1, 3).utc.beginning_of_day
    date_str = time.strftime("#{'time.formats.full_display_no_time'.translate}")
    time_zone = time.strftime("%Z")
    members = [members(:f_mentor), members(:f_student)]
    program = programs(:albers)

    Member.stubs(:get_chronus_calendar_meeting_slots).returns([{start_time: time + 23.hours, end_time: time.utc + 24.hours}])

    calendar_meetings = []
    calendar_meetings << {start_time: time + 2.hours + 15.minutes, end_time: time + 5.hours}
    calendar_meetings << {start_time: time + 4.hours, end_time: time + 5.hours}
    calendar_meetings << {start_time: time + 10.hours, end_time: time + 11.hours}
    calendar_meetings << {start_time: time + 12.hours, end_time: time + 13.hours + 15.minutes}
    calendar_meetings_hash = {busy_slots: calendar_meetings}

    CalendarQuery.stubs(:get_merged_busy_slots_for_member).returns(calendar_meetings_hash)
    program.stubs(:enhanced_meeting_scheduler_enabled?).returns(true)

    free_slots = []
    free_slots << {start: time + 8.5.hours, end: time + 10.hours}
    free_slots << {start: time + 11.hours, end: time + 12.hours}
    free_slots << {start: time + 13.hours + 30.minutes, end: time + 19.hours}
    assert_equal free_slots, Member.get_members_free_slots_after_meetings(date_str, members, {time_zone: time_zone, program: program})
    
    end_date_str = (time + 1.day).strftime("#{'time.formats.full_display_no_time'.translate}")
    free_slots << {start: time + 32.5.hours, end: time + 43.hours}
    assert_equal free_slots, Member.get_members_free_slots_after_meetings(date_str, members, {time_zone: time_zone, program: program, end_date_str: end_date_str})

    time = Time.new(2018, 1, 1).utc.beginning_of_day
    date_str = time.strftime("#{'time.formats.full_display_no_time'.translate}")
    assert time.sunday?
    assert_equal [], Member.get_members_free_slots_after_meetings(date_str, members, {time_zone: time_zone, program: program})
  end

  def test_get_members_dnd_times
    time = DateTime.new(2018, 1, 3).utc.beginning_of_day
    date_str = time.strftime("#{'time.formats.full_display_no_time'.translate}")
    time_zone = time.strftime("%Z")
    members = [members(:f_mentor), members(:f_student)]
    program = programs(:albers)

    program.stubs(:enhanced_meeting_scheduler_enabled?).returns(false)
    assert_equal [], Member.get_members_dnd_times(date_str, date_str, members, time_zone, program: program)

    free_slots = []
    free_slots << {start_time: time, end_time: time + 8.5.hours}
    free_slots << {start_time: time + 19.hours, end_time: time + 24.hours}
    free_slots << {start_time: time + 24.hours, end_time: time + 24.hours + 8.5.hours}
    free_slots << {start_time: time + 24.hours + 19.hours, end_time: time + 24.hours + 24.hours}

    program.stubs(:enhanced_meeting_scheduler_enabled?).returns(true)
    assert_equal free_slots, Member.get_members_dnd_times(date_str, date_str, members, time_zone, program: program)        
  end

  def test_get_default_dnd_times
    mentor = members(:f_mentor)
    student = members(:f_student)
    mentor_student = members(:f_mentor_student)
    mentor.stubs(:time_zone).returns("Atlantic/Stanley") # -03:00
    student.stubs(:time_zone).returns("Asia/Tokyo") # +09:00
    mentor_student.stubs(:time_zone).returns("Etc/UTC") # +00:00

    start_time = DateTime.new(2018, 03, 02, 00, 00)
    dnd_times = [{start_time: start_time + 3.hours, end_time: start_time + 11.5.hours}, {start_time: start_time + 22.hours, end_time: start_time + 27.hours}, {start_time: start_time + 27.hours, end_time: start_time + 51.hours}]
    
    assert_equal dnd_times, Member.get_default_dnd_times("March 03, 2018", "March 03, 2018", [mentor], "+09:00")

    start_time = DateTime.new(2018, 03, 03, 00, 00)
    dnd_times = [{start_time: start_time - 9.hours, end_time: start_time + 15.hours}, {start_time: start_time + 15.hours, end_time: start_time + 39.hours}, {start_time: start_time, end_time: start_time + 24.hours}, {start_time: start_time + 24.hours, end_time: start_time + 48.hours}]
    assert_equal dnd_times, Member.get_default_dnd_times("March 03, 2018", "March 03, 2018", [student, mentor_student], "-03:00")
  end

  def test_get_dnd_times_in_timezones
    start_time = DateTime.new(2018, 03, 17, 00, 00)
    dnd_times = [{start_time: start_time - 5.5.hours, end_time: start_time + 18.5.hours}, {start_time: start_time + 18.5.hours, end_time: start_time + 18.5.hours + 1.day}, {start_time: start_time, end_time: start_time + 1.day}, {start_time: start_time + 1.day, end_time: start_time + 2.days}]
    assert_equal dnd_times, Member.get_dnd_times_in_timezones(start_time, ["Asia/Kolkata", "Etc/UTC"])
  end

  def test_get_default_dnd_time
    # weekend
    start_time = DateTime.new(2018, 03, 17, 00, 00).in_time_zone("Etc/UTC")
    assert_equal [{start_time: start_time, end_time: start_time + 1.day}], Member.get_default_dnd_time(start_time)
    
    start_time = DateTime.new(2018, 03, 18, 00, 00).in_time_zone("Etc/UTC")
    assert_equal [{start_time: start_time, end_time: start_time + 1.day}], Member.get_default_dnd_time(start_time)

    # weekday
    start_time = DateTime.new(2018, 03, 19, 00, 00).in_time_zone("Etc/UTC")
    assert_equal [{start_time: start_time, end_time: start_time + 8.5.hours}, {start_time: start_time + 19.hours, end_time: start_time + 24.hours}], Member.get_default_dnd_time(start_time)
  end

  def test_get_dnd_hash
    start_time = DateTime.new(2018, 03, 17, 00, 00).in_time_zone("Etc/UTC")
    assert_equal ({start_time: start_time + 6.hours, end_time: start_time + 9.hours}), Member.get_dnd_hash({start_time: {hour: 6, min: 0, sec: 0}, end_time: {hour: 9, min: 0, sec: 0}}, start_time)
  end

  def test_round_off_slots
    time = Time.new(2018, 1, 1).utc
    slots = []
    slots << {start_time: time, end_time: time + 1.hours}
    slots << {start_time: time + 15.minutes, end_time: time + 45.minutes}
    slots << {start_time: time + 45.minutes, end_time: time + 1.hours + 15.minutes}
    assert_equal [{start_time: time, end_time: time + 1.hours}, {start_time: time, end_time: time + 1.hours}, {start_time: time + 30.minutes, end_time: time + 1.hours + 30.minutes}], Member.round_off_slots(slots)
  end

  def test_ceil
    time = Time.new(2018, 1, 1).utc
    assert_equal time, Member.ceil(time, 30.minutes)
    assert_equal time + 30.minutes, Member.ceil(time + 30.minutes, 30.minutes)
    assert_equal time + 30.minutes, Member.ceil(time + 10.minutes, 30.minutes)
    assert_equal time + 1.hours, Member.ceil(time + 50.minutes, 30.minutes)
  end

  def test_floor
    time = Time.new(2018, 1, 1).utc
    assert_equal time, Member.floor(time, 30.minutes)
    assert_equal time + 30.minutes, Member.floor(time + 30.minutes, 30.minutes)
    assert_equal time, Member.floor(time + 10.minutes, 30.minutes)
    assert_equal time + 30.minutes, Member.floor(time + 50.minutes, 30.minutes)
  end

  def test_password_expired
    programs(:org_primary).security_setting.update_attributes!(password_expiration_frequency: 1)
    member = members(:f_admin)
    member.update_attributes!(email: SUPERADMIN_EMAIL, password_updated_at: Time.now - 3.days)
    assert_false member.password_expired?

    member = members(:f_mentor)
    member.update_attributes!(password_updated_at: Time.now - 3.days)
    assert member.password_expired?
  end

  def test_most_recent_user
    member = members(:f_student)
    users(:f_student_pbe).update_attributes!(last_seen_at: 2.days.ago)
    users(:f_student).update_attributes!(last_seen_at: Time.now)
    assert_equal users(:f_student), member.most_recent_user

    assert_nil members(:dormant_member).most_recent_user
  end

  def test_member_ids_of_users
    users = users(:f_student, :f_mentor, :f_student)
    assert_equal_unordered users.collect(&:member_id).uniq, Member.member_ids_of_users(user_ids: users.collect(&:id))
    assert_equal_unordered users.collect(&:member_id).uniq, Member.member_ids_of_users(users: users)
  end

  def test_get_recently_visited_program_from_activity_log
    member = members(:f_mentor)
    assert_equal programs(:albers), member.get_recently_visited_program_from_activity_log

    ActivityLog.log_activity(users(:f_mentor_pbe), ActivityLog::Activity::PROGRAM_VISIT)
    assert_equal programs(:pbe), member.get_recently_visited_program_from_activity_log

    member = members(:foster_mentor1)
    assert_equal programs(:foster), member.get_recently_visited_program_from_activity_log
  end

  def test_create_login_token_and_send_email
    member = members(:foster_mentor1)

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      assert_difference "member.login_tokens.count", 1 do
        member.create_login_token_and_send_email("uniq_token")
      end
    end

    Organization.any_instance.stubs(:mobile_view_enabled?).returns(false)
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference "member.login_tokens.count", 1 do
        member.create_login_token_and_send_email("uniq_token")
      end
    end

    member = members(:dormant_member)
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      assert_difference "member.login_tokens.count", 1 do
        member.create_login_token_and_send_email("uniq_token")
      end
    end
  end

  def test_send_report_alert
    member = members(:f_admin)
    user = users(:f_admin_nwen)
    program = programs(:nwen)
    program1 = programs(:albers)
    ChronusMailer.expects(:deliver_now).twice
    ChronusMailer.expects(:program_report_alert).with(user, "alerts").returns(ChronusMailer)
    member.send_report_alert([program], { program => "alerts", program1 => "alerts" })
    ChronusMailer.expects(:organization_report_alert).with(member, { program => "alerts", program1 => "alerts" }).returns(ChronusMailer)
    member.send_report_alert([program, program1], { program => "alerts", program1 => "alerts" })
    member.send_report_alert([program, program1], { "a" => "alerts","b" => "alerts" })
    member.send_report_alert([program], { "a" => "alerts","b" => "alerts" })
  end

  def test_presence_of_calendar_sync_count
    member = members(:f_student)
    assert member.calendar_sync_count
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :calendar_sync_count do
      member.calendar_sync_count = nil
      member.save!
    end
  end

  private

  def date_formatter(time_object, start_of_day = true)
    time_object.send(start_of_day ? "beginning_of_day" : "end_of_day")
  end
end
