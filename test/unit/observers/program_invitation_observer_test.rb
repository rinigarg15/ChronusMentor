require_relative './../../test_helper.rb'

class ProgramInvitationObserverTest < ActiveSupport::TestCase

  def test_before_create_should_check_for_duplicate_invitation
    program = programs(:albers)

    assert_no_difference 'CampaignManagement::ProgramInvitationCampaign.count' do
      @program_invitation = program.program_invitations.create!(:sent_to => "robert@example.com", :program => program, :user => users(:f_admin_pbe), :role_names => [RoleConstants::STUDENT_NAME], :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE)
    end
  end

  def test_after_create_should_create_jobs_for_all_campaign_messages_and_send_first_message_immediately_if_skip_sending_instantly_is_false
    program = programs(:albers)

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          @program_invitation = program.program_invitations.create!(:sent_to => "aaaaa@abc.com", :program => program, :user => users(:f_admin_pbe), :role_names => [RoleConstants::STUDENT_NAME], :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE)
        end
      end
    end

    assert_equal @program_invitation.created_at, @program_invitation.sent_on
    assert @program_invitation.is_sender_admin?

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal "aaaaa@abc.com", delivered_email.to[0]
    assert_match( "Invitation to join Albers Mentor Program as a student", delivered_email.subject)
    assert_match("I would like to invite you to join", get_html_part_from(delivered_email))
  end

  def test_after_create_should_not_create_jobs_for_all_campaign_messages_and_send_first_message_immediately_if_skip_sending_instantly_is_true
    program = programs(:albers)
    ProgramInvitation.any_instance.expects(:invitee_already_member?).never
    ProgramInvitation.any_instance.expects(:send_invitation).never
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          @program_invitation = program.program_invitations.create!(:sent_to => "aaaaa@abc.com", :program => program, :user => users(:f_admin_pbe), :role_names => [RoleConstants::STUDENT_NAME], :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE, :skip_observer => true)
        end
      end
    end

    assert_nil @program_invitation.sent_on
  end

  def test_after_create_should_update_failed_sent_invitation_on_exception
    program = programs(:albers)
    CampaignManagement::ProgramInvitationCampaignMessageJob.any_instance.expects(:create_personalized_message).once.returns(false)
    assert_no_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 3 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          @invitation = program.program_invitations.create!(:sent_to => "aaaaa@abc.com", :user => users(:f_admin_pbe), :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE)
        end
      end
    end

    assert CampaignManagement::ProgramInvitationCampaignMessageJob.where(:abstract_object_id => @invitation.id).first.failed
  end

  def test_after_update_should_clear_pending_jobs_on_increment_use_count
    program = programs(:albers)
    invitation = ProgramInvitation.first
    assert invitation.is_sender_admin?

    assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', -2 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', -1 do
        invitation.increment(:use_count)
        invitation.save
      end
    end
  end


  def test_after_update_should_do_nothing_when_skip_observer_is_set
    program = programs(:albers)
    invitation = ProgramInvitation.first
    assert invitation.is_sender_admin?
    invitation.skip_observer = true

    CampaignManagement::ProgramInvitationCampaign.any_instance.expects(:stop_program_invitation_campaign).never
    CampaignManagement::ProgramInvitationCampaign.any_instance.expects(:start_program_invitation_campaign_and_send_first_campaign_message).never
    ProgramInvitation.any_instance.expects(:saved_change_to_sent_on?).never
    ProgramInvitation.any_instance.expects(:get_current_programs_program_invitation_campaign).never

  end

  def test_after_create_invitation_send_by_end_user_should_not_create_remainder_jobs
    program = programs(:albers)

    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count' do
        assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
          @program_invitation = ProgramInvitation.create!(:sent_to => "aaaaa@abc.com", :program => program, :role_names => [RoleConstants::STUDENT_NAME], :message => "some invitation message", :user => users(:f_student), :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE)
        end
      end
    end

    assert_equal @program_invitation.created_at, @program_invitation.sent_on
    assert_false @program_invitation.is_sender_admin?

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal "aaaaa@abc.com", delivered_email.to[0]
    assert_equal "Invitation from student example to join #{program.name} as a student!", delivered_email.subject
    assert_match("some invitation message", get_html_part_from(delivered_email))
  end

  def test_expects_is_sender_admin_param_in_program_invitation_send_invitation
    program = programs(:albers)
    ProgramInvitation.any_instance.expects(:send_invitation).with(program.program_invitation_campaign, skip_sending_instantly: false, is_sender_admin: false).once
    ProgramInvitation.create!(:sent_to => "aaaaa@abc.com", :program => program, :role_names => [RoleConstants::STUDENT_NAME], :message => "some invitation message", :user => users(:f_student), :role_type => ProgramInvitation::RoleType::ASSIGN_ROLE)
  end

end