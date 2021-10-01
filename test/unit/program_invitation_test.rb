require_relative './../test_helper.rb'

class ProgramInvitationTest < ActiveSupport::TestCase
  # Sets up program and admin for it
  def setup
    super
    @admin = users(:f_admin)
    @program = programs(:albers)
  end

  def test_scopes
    ProgramInvitation.destroy_all
    assert ProgramInvitation.for_mentors.empty? #tODO
    assert ProgramInvitation.for_students.empty?
    assert ProgramInvitation.for_role(RoleConstants::MENTOR_NAME).empty?
    assert ProgramInvitation.for_role(RoleConstants::STUDENT_NAME).empty?

    mentor_invite = ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    assert_equal [mentor_invite], ProgramInvitation.for_mentors.reload
    assert ProgramInvitation.for_students.empty?
    assert_equal [mentor_invite], ProgramInvitation.for_role(RoleConstants::MENTOR_NAME).reload
    assert ProgramInvitation.for_role(RoleConstants::STUDENT_NAME).empty?

    student_invite = ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::STUDENT_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    assert_equal [mentor_invite], ProgramInvitation.for_mentors.reload
    assert_equal [student_invite], ProgramInvitation.for_students.reload
    assert_equal [mentor_invite], ProgramInvitation.for_role(RoleConstants::MENTOR_NAME).reload
    assert_equal [student_invite], ProgramInvitation.for_role(RoleConstants::STUDENT_NAME).reload

    mentor_student_invite = ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    assert_equal [mentor_invite, mentor_student_invite], ProgramInvitation.for_mentors.reload
    assert_equal [student_invite, mentor_student_invite], ProgramInvitation.for_students.reload
    assert_equal [mentor_invite, mentor_student_invite], ProgramInvitation.for_role(RoleConstants::MENTOR_NAME).reload
    assert_equal [student_invite, mentor_student_invite], ProgramInvitation.for_role(RoleConstants::STUDENT_NAME).reload
  end

  def test_for_roles
    mentor_invite = ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    student_invite = ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::STUDENT_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    student_invite_ids = ProgramInvitation.for_role([RoleConstants::STUDENT_NAME]).pluck(:id)
    mentor_invite_ids = ProgramInvitation.for_role([RoleConstants::MENTOR_NAME]).pluck(:id)
    both_invite_ids = ProgramInvitation.for_role([RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]).pluck(:id)

    assert student_invite_ids.include?(student_invite.id)
    assert_false student_invite_ids.include?(mentor_invite.id)
    assert_false mentor_invite_ids.include?(student_invite.id)
    assert mentor_invite_ids.include?(mentor_invite.id)
    assert both_invite_ids.include?(student_invite.id)
    assert both_invite_ids.include?(mentor_invite.id)
  end

  def test_with_fixed_roles
    invite = ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    assert ProgramInvitation.with_fixed_roles.pluck(:id).include?(invite.id)

    invite.update_attribute(:role_type, ProgramInvitation::RoleType::ALLOW_ROLE)
    assert_false ProgramInvitation.with_fixed_roles.pluck(:id).include?(invite.id)
  end

  def test_non_expired_arel
    expired_invite = programs(:albers).program_invitations[0]
    expired_invite.update_attribute(:expires_on, Time.new(1900))
    assert expired_invite.expired?
    assert programs(:albers).program_invitations.include?(expired_invite)
    assert_false programs(:albers).program_invitations.non_expired.include?(expired_invite)
  end

  def test_in_date_range
    invite = programs(:albers).program_invitations[0]
    invite.update_attribute(:sent_on, 10.days.ago)
    assert ProgramInvitation.in_date_range(11.days.ago, 9.days.ago).include?(invite)
    assert_false ProgramInvitation.in_date_range(5.days.ago, Time.now).include?(invite)
  end

  def test_unfailed_arel
    invite = program_invitations(:mentor)
    assert_equal [invite], ProgramInvitation.where(id: invite.id).unfailed

    event_log = invite.event_logs.first
    event_log.event_type = CampaignManagement::EmailEventLog::Type::FAILED
    event_log.save
    assert_empty ProgramInvitation.where(id: invite.id).unfailed

    event_log.event_type = CampaignManagement::EmailEventLog::Type::DELIVERED
    event_log.save
    assert_equal [invite], ProgramInvitation.where(id: invite.id).unfailed
  end

  def test_create_and_belongs_to_program
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'ProgramInvitation.count', 1 do
        @invite = ProgramInvitation.create!(
          sent_to: 'abc@chronus.com',
          user: @admin,
          program: @program,
          role_names: [RoleConstants::STUDENT_NAME],
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)

        assert_equal @program, @invite.program
      end
    end

    assert_equal @program, @invite.program
    assert_equal @admin, @invite.user
    assert_equal [RoleConstants::STUDENT_NAME], @invite.role_names
    assert @invite.is_sender_admin?

    # Check the virtual attribute
    delivered_email = ActionMailer::Base.deliveries.first
    assert_equal @invite.sent_to, delivered_email.to[0]
    assert_match("Invitation to join Albers Mentor Program as a student", delivered_email.subject)
    assert_match("I would like to invite you to join", get_html_part_from(delivered_email))
  end

  def test_invite_as_mentor
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'ProgramInvitation.count', 1 do
        @invite = ProgramInvitation.create!(
          sent_to: 'abc@chronus.com',
          user: @admin,
          program: @program,
          role_names: [RoleConstants::MENTOR_NAME],
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)
      end
    end

    # Check the virtual attribute
    assert_equal([RoleConstants::MENTOR_NAME], @invite.role_names)

    delivered_email = ActionMailer::Base.deliveries.first
    assert_equal @invite.sent_to, delivered_email.to[0]
    assert_match("Invitation to join Albers Mentor Program as a mentor", delivered_email.subject)
    assert_match("I would like to invite you to join", get_html_part_from(delivered_email))
  end

  # sent_to cannot be blank
  def test_sent_to_is_required
    assert_no_difference 'ProgramInvitation.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :sent_to do
        ProgramInvitation.create!(
          user: @admin,
          program: @program,
          role_names: [RoleConstants::STUDENT_NAME],
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)
      end
    end
  end

  def test_role_type_is_required
    assert_no_difference 'ProgramInvitation.count' do
      assert_raise_error_on_field ActiveRecord::RecordInvalid, :role_type do
        ProgramInvitation.create!(
          sent_to: 'abc@chronus.com',
          user: @admin,
          program: @program,
          role_names: [RoleConstants::MENTOR_NAME])
      end
    end
  end

  def test_program_is_required
    assert_no_difference 'ProgramInvitation.count' do
      assert_raise AuthorizationManager::ProgramNotSetException do
        ProgramInvitation.create!(
          sent_to: 'abc@chronus.com',
          user: @admin,
          role_names: [RoleConstants::STUDENT_NAME],
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)
      end
    end
  end

  def test_assign_and_allow_type
    program_invitation = program_invitations(:mentor)
    assert program_invitation.assign_type?
    assert_false program_invitation.allow_type?

    program_invitation.role_type = ProgramInvitation::RoleType::ALLOW_ROLE
    assert_false program_invitation.assign_type?
    assert program_invitation.allow_type?
  end

  def test_build_member_from_invite
    program_invitation = program_invitations(:mentor)
    assert_no_difference "Member.count" do
      member = program_invitation.build_member_from_invite
      assert_equal program_invitation.sent_to, member.email
      assert_equal program_invitation.program.organization, member.organization
    end
  end

  def test_check_admin_invite
    # Student tries to send invite to admin
    @invite = ProgramInvitation.new(
      sent_to: 'abc@chronus.com',
      user: users(:f_student),
      program: @program,
      role_names: [RoleConstants::ADMIN_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    @invite.valid?
    assert @invite.errors[:user]
    @invite.user = users(:f_admin)
    @invite.valid?

    # Give students admin inviting privilege.
    add_role_permission(fetch_role(:albers, :student),'invite_admins')
    @invite.user = users(:f_student).reload
    @invite.valid?

    assert @invite.errors.empty?
    assert_difference 'ProgramInvitation.count' do
      @invite.save!
    end
  end

  def test_check_can_invite_friends
    # Mentor tries to send invite in a program with disabled friendly invite
    join_settings = {
      RoleConstants::STUDENT_NAME =>[RoleConstants::JoinSetting::INVITATION,
                                     RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE]
                     }

    user = users(:f_student)
    assert_false user.is_mentor?
    @program.update_join_settings({RoleConstants::STUDENT_NAME =>[RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTOR_CAN_INVITE]})
    @invite = ProgramInvitation.new(
      sent_to: 'abc@chronus.com',
      user: user,
      program: @program,
      role_names: [RoleConstants::STUDENT_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')

    @invite.valid?
    assert @invite.errors[:user]
    @program.update_join_settings({RoleConstants::STUDENT_NAME =>[RoleConstants::JoinSetting::INVITATION,RoleConstants::InviteRolePermission::MENTEE_CAN_INVITE]})
    @invite.user = user.reload
    @invite.valid?

    assert @invite.errors.empty?
    assert_difference 'ProgramInvitation.count' do
      @invite.save!
    end
  end

  def test_should_create_program_invitation_for_mentor_mentee_user
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'ProgramInvitation.count', 1 do
        @invite = ProgramInvitation.create!(
          sent_to: 'abc@chronus.com',
          user: @admin,
          program: @program,
          role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
          message: 'some message')

        assert_equal @program, @invite.program
      end
    end

    assert_equal([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], @invite.role_names)
  end

  def test_invitation_expired
    ProgramInvitation.skip_timestamping do
      ProgramInvitation.create!(
        sent_to: 'abc@chronus.com',
        user: @admin,
        program: @program,
        role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
        role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
        message: 'some message',
        created_at: 31.days.ago)
    end
    p = ProgramInvitation.last
    assert(p.expired?)

    ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')
    p = ProgramInvitation.last
    assert(!p.expired?)
  end

  def test_days_since_sent
    ProgramInvitation.skip_timestamping do
      ProgramInvitation.create!(
        sent_to: 'abc@chronus.com',
        user: @admin,
        program: @program,
        role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
        role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
        message: 'some message',
        created_at: 31.days.ago)
    end
    p = ProgramInvitation.last
    assert_equal(31, p.days_since_sent)

    ProgramInvitation.skip_timestamping do
      ProgramInvitation.create!(
        sent_to: 'abc@chronus.com',
        user: @admin,
        program: @program,
        role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
        role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
        message: 'some message',
        created_at: 30.days.ago)
    end
    p = ProgramInvitation.last
    assert_equal(30, p.days_since_sent)

    ProgramInvitation.create!(
      sent_to: 'abc@chronus.com',
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')
    p = ProgramInvitation.last
    assert_equal(0, p.days_since_sent)
  end

  def test_resend_expired_invitation
    inviter = users(:f_admin)

    ProgramInvitation.skip_timestamping do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          assert_difference 'ProgramInvitation.count', 1 do
            @invite = ProgramInvitation.create!(
              sent_to: 'abc@chronus.com',
              user: inviter,
              program: programs(:albers),
              role_names: [RoleConstants::STUDENT_NAME],
              role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
              created_at: 40.days.ago)
          end
        end
      end
    end

    assert_equal @program, @invite.program
    assert @invite.expired?
    #for expired invitation there will be no remainder mails. so deleting remainder jobs.
    @invite.campaign_jobs.delete_all

    ActionMailer::Base.deliveries.clear
    assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
        assert_difference 'JobLog.count' do
          assert_difference('ActionMailer::Base.deliveries.size') do
            assert_no_difference 'ProgramInvitation.count' do
              ProgramInvitation.send_invitations([@invite.id], @invite.program_id, inviter.id, update_expires_on: true, skip_sending_instantly: true, is_sender_admin: true, action_type: "Resend Invitations")
            end
          end
        end
      end
    end

    assert !@invite.reload.expired?
    assert_time_is_equal_with_delta(Time.now.to_i, @invite.sent_on.to_i)
    assert_time_is_equal_with_delta((Time.now + 30.days).to_i, @invite.expires_on.to_i)

    delivered_email = ActionMailer::Base.deliveries.first
    assert_equal @invite.sent_to, delivered_email.to[0]
    assert_match("Invitation to join Albers Mentor Program as a student", delivered_email.subject)
    email_content = ActionController::Base.helpers.strip_tags(get_html_part_from(delivered_email)).squish
    assert_match("I would like to invite you to join", email_content)
    assert_equal 1, email_content.scan(/This is an automated email \- please don't reply/).size
    assert_equal 1, email_content.scan(/Contact Administrator for any questions./).size
  end

  def test_resend_non_expired_invitation
    inviter = users(:f_admin)
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          assert_difference 'ProgramInvitation.count', 1 do
            @invite = ProgramInvitation.create!(
              sent_to: 'abc@chronus.com',
              user: inviter,
              program: programs(:albers),
              role_names: [RoleConstants::STUDENT_NAME],
              role_type: ProgramInvitation::RoleType::ASSIGN_ROLE
            )
          end
        end
      end
    end

    assert_equal @program, @invite.program
    assert_false @invite.expired?

    ActionMailer::Base.deliveries.clear
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count' do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
          assert_no_difference 'ProgramInvitation.count' do
            assert_difference 'JobLog.count' do
              ProgramInvitation.send_invitations([@invite.id], @invite.program_id, inviter.id, update_expires_on: true, skip_sending_instantly: true, is_sender_admin: true, action_type: "Resend Invitations")
            end
          end
        end
      end
    end
    @invite = @invite.reload

    assert_time_is_equal_with_delta(Time.now.to_i, @invite.sent_on.to_i)
    assert_time_is_equal_with_delta((Time.now + 30.days).to_i, @invite.expires_on.to_i)

    delivered_email = ActionMailer::Base.deliveries.first
    assert_equal @invite.sent_to, delivered_email.to[0]
    assert_match("Invitation to join Albers Mentor Program as a student", delivered_email.subject)
    assert_match("I would like to invite you to join", get_html_part_from(delivered_email))
  end

  def test_sent_to_member
    dormant_member = create_member(organization: programs(:org_primary), first_name: "dormant", last_name: "member", email: "dormant@domain.com", state: Member::Status::DORMANT)
    invite = ProgramInvitation.create!(
      sent_to: dormant_member.email,
      user: @admin,
      program: @program,
      role_names: [RoleConstants::MENTOR_NAME],
      role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
      message: 'some message')
    assert_equal dormant_member, invite.sent_to_member
  end

  def test_recent_scope
    invs = []
    ProgramInvitation.destroy_all

    4.times do |i|
      ProgramInvitation.skip_timestamping do
        invs << ProgramInvitation.create!(
          sent_to: "abc_#{i}@chronus.com",
          user: users(:f_admin),
          program: programs(:albers),
          role_names: [RoleConstants::STUDENT_NAME],
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE,
          message: 'some message',
          created_at: (10 + i).days.ago)
      end
    end

    assert_equal(invs[0..0], ProgramInvitation.recent(11.days.ago))
    assert_equal(invs[0..1], ProgramInvitation.recent(12.days.ago))
    assert_equal(invs[0..2], ProgramInvitation.recent(13.days.ago))
    assert_equal(invs[0..3], ProgramInvitation.recent(14.days.ago))
  end

  def test_update_use_count_should_increment_use_count_value
    program = programs(:albers)
    invitation = program.program_invitations.create!(sent_to: "aaaaa@abc.com", message: "message", user: users(:f_admin_pbe), role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)
    assert_difference 'invitation.reload.use_count', 1 do
      invitation.update_use_count
    end
  end

  def test_get_first_job_should_return_first_job
    program = programs(:albers)
    campaign = program.program_invitation_campaign
    program_invitation = ProgramInvitation.first
    campaign.cleanup_jobs_for_object_ids(program_invitation)
    campaign.create_campaign_message_jobs([program_invitation.id], program_invitation.created_at)
    first_message_id = campaign.campaign_messages.sort_by(&:duration).first.id
    first_job = CampaignManagement::ProgramInvitationCampaignMessageJob.pending.where(abstract_object_id: program_invitation.id, campaign_message_id: first_message_id).first
    assert_equal first_job, program_invitation.get_first_job.first
  end

  def test_program_invitation_can_have_many_campaign_jobs
    invitation = program_invitations(:mentor)
    assert_equal 2, invitation.campaign_jobs.count
    campaign_message = invitation.get_current_programs_program_invitation_campaign.campaign_messages.first
    invitation.campaign_jobs.create!(campaign_message: campaign_message, run_at: DateTime.parse("20140204"))

    invitation.reload
    assert_equal 3, invitation.campaign_jobs.count
    assert_difference "CampaignManagement::ProgramInvitationCampaignMessageJob.count", -3 do
      invitation.destroy
    end
  end

  def test_program_invitation_kendo_filter_scope_for_expired
    filter = {"value" => "Expired"}
    assert_equal [], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    invitation = program_invitations(:mentor)
    invitation.update_attributes!(expires_on: 2.years.ago)
    assert_equal [invitation.id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
  end

  def test_program_invitation_kendo_filter_scope_for_pending
    filter = {"value" => "Pending"}
    assert_equal_unordered [program_invitations(:mentor).id, program_invitations(:student).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    invitation = program_invitations(:student)
    invitation.update_attributes!(use_count: 1)
    assert_equal [program_invitations(:mentor).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    event_log = program_invitations(:mentor).event_logs.first
    event_log.event_type = CampaignManagement::EmailEventLog::Type::FAILED
    event_log.save

    assert_equal [], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
  end

  def test_program_invitation_kendo_filter_scope_for_accepted
    filter = {"value" => "Accepted"}
    assert_equal [], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    invitation = program_invitations(:mentor)
    invitation.update_attributes!(use_count: 1)
    assert_equal [invitation.id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
  end


  def test_program_invitation_kendo_filter_scope_for_mail_events
    filter = {"value" => "Opened"}
    assert_equal [program_invitations(:mentor).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    filter = {"value" => "Opened and Clicked"}
    assert_equal [program_invitations(:mentor).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    filter = {"value" => "Sent"}
    assert_equal_unordered [program_invitations(:student).id, program_invitations(:mentor).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    filter = {"value" => "Sent and Delivered"}
    assert_equal [], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
    invitation = program_invitations(:student)
    invitation.emails.first.event_logs.create!(event_type: CampaignManagement::EmailEventLog::Type::DELIVERED, timestamp: Time.now)
    assert_equal [program_invitations(:student).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    filter = {"value" => "Not Delivered"}
    assert_equal [], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
    invitation.emails.first.event_logs.create!(event_type: CampaignManagement::EmailEventLog::Type::FAILED, timestamp: Time.now)
    assert_equal [program_invitations(:student).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
  end

  def test_program_invitation_kendo_filter_scope_for_mail_events_should_not_return_duplicate_entries
    filter = {"value" => "Opened"}
    assert_equal [program_invitations(:mentor).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)

    # Create opened event for the second email as well
    invitation = program_invitations(:mentor)
    invitation.emails.last.event_logs.create!(event_type: CampaignManagement::EmailEventLog::Type::OPENED, timestamp: Time.now)
    assert_equal [program_invitations(:mentor).id], ProgramInvitation::KendoScopes.status_filter(filter).collect(&:id)
  end


  def test_kendo_scope_roles_filter_for_allow_roles
    filter = {"value" => "Not Specified"}

    output = ProgramInvitation::KendoScopes.roles_filter(filter)
    assert_equal [], output

    program_invitations(:student).update_attributes!(role_type: ProgramInvitation::RoleType::ALLOW_ROLE)
    output = ProgramInvitation::KendoScopes.roles_filter(filter)
    assert_equal [program_invitations(:student).id], output.collect(&:id)
  end

  def test_kendo_scope_roles_filter_for_cutom_role_name
    # admin customized term that we show in the kendo list is Mentor
    filter = {"value" => "Mentor"}

    output = ProgramInvitation::KendoScopes.roles_filter(filter)
    assert_equal [program_invitations(:mentor).id], output.collect(&:id)
  end

  def test_kendo_roles_sort_for_custom_role_name
    output = ProgramInvitation::KendoScopes.roles_sort("asc")
    assert_equal [program_invitations(:mentor).id, program_invitations(:student).id], output.collect(&:id)
    output = ProgramInvitation::KendoScopes.roles_sort("desc")
    assert_equal [program_invitations(:student).id, program_invitations(:mentor).id], output.collect(&:id)

    # Extra test to make sure it is infact picking up from the customized term and not directly from the roles name
    mentor_role = programs(:albers).find_role(RoleConstants::MENTOR_NAME)
    mentee_role = programs(:albers).find_role(RoleConstants::STUDENT_NAME)

    mentor_role.customized_term.update_attributes!(term: "bbbbb")
    mentee_role.customized_term.update_attributes!(term: "aaaaa")
    output = ProgramInvitation::KendoScopes.roles_sort("asc")
    assert_equal [program_invitations(:student).id, program_invitations(:mentor).id], output.collect(&:id)
  end


  def test_kendo_roles_sort_should_list_allow_roles_as_well

    invite = ProgramInvitation.create!(
    sent_to: 'abc@chronus.com',
    user: users(:f_admin),
    program: programs(:albers),
    role_names: [RoleConstants::STUDENT_NAME],
    role_type: ProgramInvitation::RoleType::ALLOW_ROLE
    )

    output = ProgramInvitation::KendoScopes.roles_sort("asc")
    assert_equal [program_invitations(:mentor).id, program_invitations(:student).id, invite.id], output.collect(&:id)
  end

  def test_kendo_sender_sort_should_sort_based_on_the_sender_name
    #to make sure invitations count is same after sorting.
    program = program_invitations(:mentor).program
    assert_equal 2, program.program_invitations.count

    # Sender names are Freaking Admin and Student respectively
    output = ProgramInvitation::KendoScopes.sender_sort("asc")
    assert_equal [program_invitations(:mentor).id, program_invitations(:student).id], output.collect(&:id)
    assert_equal 2, output.count

    output = ProgramInvitation::KendoScopes.sender_sort("desc")
    assert_equal [program_invitations(:student).id, program_invitations(:mentor).id], output.collect(&:id)
    assert_equal 2, output.count
  end

  # Freakin Admin
  # Student Example

  def test_kendo_sender_filter_should_filter_on_sender_name
    output = ProgramInvitation::KendoScopes.sender_filter({"value" => "student"})
    assert_equal [program_invitations(:student).id], output.collect(&:id)

    output = ProgramInvitation::KendoScopes.sender_filter({"value" => "e"}) #e-> common character between two senders
    assert_equal_unordered [program_invitations(:student).id, program_invitations(:mentor).id], output.collect(&:id)

    output = ProgramInvitation::KendoScopes.sender_filter({"value" => "student example"})
    assert_equal [program_invitations(:student).id], output.collect(&:id)

    program = programs(:albers)
    assert_equal "Admin", program_invitations(:mentor).user.last_name
    params = {"filter"=>{"logic"=>"and", "filters"=>{"0"=>{"field"=>"sender", "operator"=>"contains", "value"=>"Admin"}}}}
    filtered_output = GenericKendoPresenter.new(ProgramInvitation, GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(program, true), params).list

    params = {"sort"=>{"0"=>{"field"=>"sender", "dir"=>"asc"}},
              "filter"=>{"logic"=>"and", "filters"=>{"0"=>{"field"=>"sender", "operator"=>"contains", "value"=>"Admin"}}}}
    sorted_and_filtered_output = GenericKendoPresenter.new(ProgramInvitation, GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(program, true), params).list

    assert_equal "Admin", filtered_output.first.user.last_name
    assert_equal sorted_and_filtered_output.count, filtered_output.count
  end

  def test_is_sender_admin
    invitation = program_invitations(:mentor)
    assert invitation.is_sender_admin?

    invitation = program_invitations(:student)
    assert_false invitation.is_sender_admin?

    invitation.user.destroy
    assert_false invitation.is_sender_admin?
  end

  def test_send_invitation_email_by_end_user_and_assign_roles_to_user
    user = users(:f_student)
    assert_false user.is_admin?

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count' do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
          assert_difference 'ProgramInvitation.count', 1 do
            @invite = ProgramInvitation.create!(
              sent_to: 'abc@chronus.com',
              user: user,
              program: programs(:albers),
              role_names: [RoleConstants::STUDENT_NAME],
              message: 'some message',
              role_type: ProgramInvitation::RoleType::ASSIGN_ROLE
            )
          end
        end
      end
    end

    assert_false @invite.is_sender_admin?
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal 'abc@chronus.com', delivered_email.to[0]
    assert_equal "Invitation from student example to join #{programs(:albers).name} as a student!", delivered_email.subject
    assert_match(/some message/, get_html_part_from(delivered_email))
    assert_match(/You have been invited by student example to join Albers Mentor Program as a student./, get_html_part_from(delivered_email))
  end

  def test_send_invitation_email_by_end_user_and_allow_user_to_choose_roles
    user = users(:f_student)
    assert_false user.is_admin?

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count' do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
          assert_difference 'ProgramInvitation.count', 1 do
            @invite = ProgramInvitation.create!(
              sent_to: 'abc@chronus.com',
              user: user,
              program: programs(:albers),
              role_names: [],
              message: 'some message',
              role_type: ProgramInvitation::RoleType::ALLOW_ROLE
            )
          end
        end
      end
    end

    assert_false @invite.is_sender_admin?
    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal 'abc@chronus.com', delivered_email.to[0]
    assert_equal "Invitation from student example to join #{programs(:albers).name} !", delivered_email.subject
    assert_match("some message", get_html_part_from(delivered_email))
    assert_match(/You have been invited by student example to join Albers Mentor Program/, get_html_part_from(delivered_email))
  end

  def test_invitee_already_member
    program_invitation = program_invitations(:mentor)
    assert_false program_invitation.invitee_already_member?

    program_invitation.sent_to = "robert@example.com"
    program_invitation.save
    assert program_invitation.invitee_already_member?

    program_invitation = program_invitations(:student)
    program_invitation.sent_to = "robert@example.com"
    program_invitation.save
    assert_false program_invitation.invitee_already_member?

    program_invitation.role_type = ProgramInvitation::RoleType::ALLOW_ROLE
    program_invitation.save
    assert program_invitation.invitee_already_member?

    program_invitation = program_invitations(:mentor)
    user = users(:f_mentor)
    assert_equal user.email, program_invitation.sent_to

    assert program_invitation.invitee_already_member?

    user.suspend_from_program!(users(:f_admin), "Suspension reason")
    assert user.suspended?

    assert_false program_invitation.invitee_already_member?

    program_invitation.update_attributes!(role_type: ProgramInvitation::RoleType::ASSIGN_ROLE)

    assert_false program_invitation.invitee_already_member?

    user.state = User::Status::ACTIVE
    user.save!
    assert user.active?
    assert program_invitation.invitee_already_member?

    user.state = User::Status::PENDING
    user.save!
    assert user.profile_pending?
    assert program_invitation.invitee_already_member?
  end

  def test_send_invitations
    invites = []
    inviter = users(:f_admin)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 4 do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 2 do
          assert_difference "ProgramInvitation.count", 2 do
            invites << ProgramInvitation.create!(
              sent_to: 'abc@chronus.com',
              user: inviter,
              program: programs(:albers),
              role_names: [],
              message: 'some message',
              skip_observer: true,
              role_type: ProgramInvitation::RoleType::ALLOW_ROLE
            )
            invites << ProgramInvitation.create!(
              sent_to: 'abc3@chronus.com',
              user: inviter,
              program: programs(:albers),
              role_names: [],
              message: 'some message',
              skip_observer: true,
              role_type: ProgramInvitation::RoleType::ALLOW_ROLE
            )
          end
        end
      end
    end
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 4 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 2 do
          assert_difference 'JobLog.count', 2 do
            ProgramInvitation.send_invitations(invites.collect(&:id), programs(:albers).id, inviter.id, skip_sending_instantly: true, is_sender_admin: true)
          end
        end
      end
    end
  end

  def test_send_invitation
    invite = nil
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          assert_difference "ProgramInvitation.count", 1 do
            invite = ProgramInvitation.create!(
              sent_to: 'abc@chronus.com',
              user: users(:f_student),
              program: programs(:albers),
              role_names: [],
              message: 'some message',
              skip_observer: true,
              role_type: ProgramInvitation::RoleType::ALLOW_ROLE
            )
          end
        end
      end
    end
    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          invite.update_attributes(sent_on: Time.now, skip_observer: true)
          invite.send_invitation(programs(:albers).program_invitation_campaign, skip_sending_instantly: true, is_sender_admin: true)
        end
      end
    end
  end

  def test_without_sender_user
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
        @invite = ProgramInvitation.create!(
          sent_to: 'abc@chronus.com',
          user: nil,
          program: programs(:albers),
          role_names: [RoleConstants::STUDENT_NAME],
          message: 'some message',
          role_type: ProgramInvitation::RoleType::ASSIGN_ROLE
        )
    end
  end

  def test_kendo_scope_pending_filters
    pending_filter = {"field" => "statuses", "operator" => "eq", "value" => "Pending"}
    invitations = ProgramInvitation::KendoScopes.status_filter(pending_filter)
    assert_equal 2, invitations.count
    invitations.first.update_attributes!(expires_on: Time.now - 1.day)
    assert_equal [invitations.last], ProgramInvitation::KendoScopes.status_filter(pending_filter)
  end

  def test_report_to_stream
    program = programs(:albers)

    ProgramInvitation.create!( sent_to: "mentormentee@chronus.com", user: users(:f_admin), program: programs(:albers), role_names: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME], role_type: ProgramInvitation::RoleType::ALLOW_ROLE, use_count: 1 )

    body = Enumerator.new { |stream| ProgramInvitation.report_to_stream(program, stream, program.program_invitation_ids, users(:f_admin).member) }
    csv_array = CSV.parse(body.to_a.join)

    expected_headers = ["Recipient", "Sent", "Valid until", "Role(s)", "Sender", "Status"]
    expected_result_hash = {
      "mentor@chronus.com" => {
        roles: "Mentor",
        sender: "Freakin Admin",
        status: "Opened and Clicked"
      },
      "mentee@chronus.com" => {
        roles: "Student",
        sender: "student example",
        status: "Sent"
      },
      "mentormentee@chronus.com" => {
        roles: "Allow user to choose (Mentor, Student)",
        sender: "Freakin Admin",
        status: "Accepted"
      }
    }

    assert_equal expected_headers, csv_array[0]
    csv_array[1..-1].each do |row|
      receipient = row[0]
      assert_equal expected_result_hash[receipient][:roles], row[3]
      assert_equal expected_result_hash[receipient][:sender], row[4]
      assert_equal expected_result_hash[receipient][:status], row[5]
    end
  end
end
