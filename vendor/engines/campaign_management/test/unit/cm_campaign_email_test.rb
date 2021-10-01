require_relative './../test_helper'

class CampaignEmailTest < ActiveSupport::TestCase

  def setup
    super
    @mentor_program_invitation = program_invitations(:mentor).id
  end

  def test_campaign_email_must_have_campaign_message_id
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    message.campaign_message_id = nil

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :campaign_message_id, "can't be blank" do
      message.save!
    end
  end

  def test_campaign_email_must_have_abstract_object_id
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    message.abstract_object_id = nil

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :abstract_object_id, "can't be blank" do
      message.save!
    end
  end

  def test_campaign_email_must_have_subject
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    message.subject = nil

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :subject, "can't be blank" do
      message.save!
    end
  end

  def test_campaign_email_must_have_source
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)
    message.source = nil

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :source, "can't be blank" do
      message.save!
    end
  end

  def test_campaign_email_can_have_many_event_logs
    message = cm_campaign_emails(:first_program_invitation_campaign_messages_first_email)

    assert_difference "CampaignManagement::EmailEventLog.count" do
      message.event_logs.create!(event_type: CampaignManagement::EmailEventLog::Type::FAILED, timestamp: Time.new(2004,01,2))
    end

    message.reload
    assert_equal 3, message.event_logs.count

    assert_difference "CampaignManagement::EmailEventLog.count", -3 do
      message.destroy
    end
  end
end
