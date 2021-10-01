require_relative './../test_helper'

class ProgramInvitationCampaignMessageTest < ActiveSupport::TestCase

  def setup
    super
    @program = programs(:albers)
    @campaign = @program.program_invitation_campaign
    @campaign_messages = @campaign.campaign_messages
    @campaign_message_1 = @campaign_messages[0]
    @campaign_message_2 = @campaign_messages[1]
    @campaign_message_3 = @campaign_messages[2]
  end

  def test_belongs_to_campaign
    assert_equal @campaign, @campaign_message_1.campaign
  end

  def test_is_duration_editable
    assert_false @campaign_message_1.is_duration_editable?
    assert @campaign_message_2.is_duration_editable?
  end

  def test_program_invitation_campaign_message_can_have_many_emails
    assert_equal 2, @campaign_message_1.emails.count
  end

  def test_deleteing_campaign_message_should_not_delete_the_corresponding_email
    assert_equal 2, @campaign_message_2.emails.size

    assert_difference "CampaignManagement::CampaignEmail.count", 0 do
      @campaign_message_2.destroy
    end
  end

  def test_campaign_email_tags_should_return_available_email_tags
    all_tags = CampaignManagement::ProgramInvitationCampaign.first.campaign_email_tags
    assert_equal 8, all_tags.count
    assert_equal_unordered ["invitor_name", "role_name", "as_role_name_articleized", "url_invitation", "invitation_expiry_date", "subprogram_or_program_name", "url_subprogram_or_program", "url_contact_admin"], all_tags.keys.collect(&:to_s)
  end

  def test_create_jobs_for_eligible_statuses
    time_now = Time.now
    invitation = program_invitations(:mentor)
    status = invitation.status
    invitation_jobs = invitation.campaign_jobs
    invitation_emails = invitation.emails
    invitation_jobs.destroy_all
    invitation_emails.destroy_all
    assert status.started_at >= (time_now - @campaign_message_2.duration.days)
    assert status.started_at >= (time_now - @campaign_message_3.duration.days)

    assert_difference "invitation_jobs.reload.size", 1 do
      @campaign_message_2.create_jobs_for_eligible_statuses(time_now)
    end

    assert_no_difference "invitation_jobs.reload.size" do
      @campaign_message_2.create_jobs_for_eligible_statuses(time_now)
    end

    @campaign_message_3.emails.create!(abstract_object_id: invitation.id, subject: "Subject", source: "Content")
    assert_no_difference "invitation_jobs.reload.size" do
      @campaign_message_3.create_jobs_for_eligible_statuses(time_now)
    end

    invitation_emails.reload.destroy_all
    status.update_column(:started_at, Time.now - (@campaign_message_3.duration.days + 1.day))
    assert_no_difference "invitation_jobs.reload.size" do
      @campaign_message_3.create_jobs_for_eligible_statuses(time_now)
    end

    status.update_column(:started_at, invitation.created_at)
    assert_difference "invitation_jobs.reload.size", 1 do
      @campaign_message_3.create_jobs_for_eligible_statuses(time_now)
    end
  end
end