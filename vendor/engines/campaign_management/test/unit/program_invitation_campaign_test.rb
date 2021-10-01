require_relative './../test_helper'

class ProgramInvitationCampaignTest < ActiveSupport::TestCase
  def test_belongs_to_program
    assert_equal programs(:albers), cm_campaigns(:cm_campaigns_3).program
  end

  def test_email_template_association
    campaign = cm_campaigns(:cm_campaigns_3)
    assert_equal_unordered campaign.campaign_messages.collect(&:email_template), campaign.email_templates
  end

  def test_start_program_invitation_campaign_should_create_jobs_for_all_campaign_messages
    program_invitation = program_invitations(:mentor)
    campaign = program_invitation.get_current_programs_program_invitation_campaign
    campaign.stop_program_invitation_campaign([program_invitation.id])
    assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 3 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
        campaign.start_program_invitation_campaign(program_invitation)
      end
    end
  end

  def test_stop_program_invitation_campaign_should_clear_pending_jobs_for_all_campaign_messages
    program_invitation = program_invitations(:mentor)
    campaign = program_invitation.get_current_programs_program_invitation_campaign
    assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', -2 do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', -1 do
        campaign.stop_program_invitation_campaign([program_invitation.id])
      end
    end
  end

  def test_start_program_invitation_campaign_and_send_first_campaign_message
    program_invitation = program_invitations(:mentor)
    campaign = program_invitation.get_current_programs_program_invitation_campaign
    campaign.stop_program_invitation_campaign([program_invitation.id])
    assert_difference('ActionMailer::Base.deliveries.size') do
      assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 2 do
        assert_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count', 1 do
          campaign.start_program_invitation_campaign_and_send_first_campaign_message(program_invitation)
        end
      end
    end

    delivered_email = ActionMailer::Base.deliveries.last
    assert_equal program_invitation.sent_to, delivered_email.to[0]
    assert_match("Invitation to join Albers Mentor Program as a mentor", delivered_email.subject)
    assert_match("Once you do that, you can fill out your profile (which we use to match you up with other participants with similar interests and goals) and participate in the program activities.", get_html_part_from(delivered_email))
  end
end