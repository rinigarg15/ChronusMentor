require_relative './../test_helper'

class AbstractCampaignMessageObserverTest < ActiveSupport::TestCase

  def test_ignore_campaign_jobs_update_if_other_params_updated
    campaign_message = cm_campaign_messages(:campaign_message_1)

    CampaignManagement::UserCampaignMessage.any_instance.expects(:handle_schedule_update).never
    campaign_message.update_attributes(sender_id: 17)
  end

  def test_skip_observer
    campaign_message = cm_campaign_messages(:campaign_message_1)
    CampaignManagement::UserCampaignMessage.any_instance.expects(:handle_schedule_update).never
    CampaignManagement::AbstractCampaign.any_instance.expects(:process!).never
    campaign_message.skip_observer = true
    campaign_message.update_attributes(duration: 12)
  end

  def test_process_duration_changes
    campaign_message = cm_campaign_messages(:campaign_message_1)
    mock_1 = campaign_message.delay
    CampaignManagement::UserCampaignMessage.any_instance.expects(:delay).once.returns(mock_1)
    CampaignManagement::UserCampaignMessage.any_instance.expects(:handle_schedule_update).once
    campaign_message.update_attributes(duration: 12)
  end

  def test_before_save_should_not_validate_any_tags_unless_it_is_a_new_campaign_message_being_created
    campaign_message = cm_campaign_messages(:campaign_message_1)
    campaign_message.duration = 23

    Mailer::Template.any_instance.expects(:validate_tags_and_widgets_through_campaign).never
    campaign_message.save!
  end

  def test_before_save_should_validate_tags_if_it_is_a_new_campaign_message_being_created
    campaign = cm_campaign_messages(:campaign_message_1).campaign
    message = campaign.campaign_messages.new(:duration => 1)
    message.build_email_template(:source => "test source", :subject => "test subject", :program_id => campaign.program_id)
    template = message.email_template
    template.belongs_to_cm = true

    CampaignManagement::UserCampaign.any_instance.expects(:get_supported_tags_and_widgets).returns([['a', 'b'], []])
    Mailer::Template.any_instance.expects(:validate_tags_and_widgets_in_subject_and_source).with(['a','b'], []).returns
    assert message.save!
  end

  def test_after_create_campaign_message_should_create_jobs_except_for_user_campaign
    program = programs(:albers)
    campaign = program.program_invitation_campaign
    email_template = Mailer::Template.new(:program_id => program.id, source: "Test", subject: "Test")
    email_template.belongs_to_cm = true

    assert_equal 1, CampaignManagement::ProgramInvitationCampaignStatus.count
    assert_difference 'CampaignManagement::ProgramInvitationCampaignMessageJob.count', 1 do
      assert_no_difference 'CampaignManagement::ProgramInvitationCampaignStatus.count' do
        campaign.campaign_messages.create!(:sender_id => programs(:albers).admin_users.first.id, :email_template => email_template, :duration => 5)
      end
    end

    uc = cm_campaigns(:active_campaign_1)
    email_template = Mailer::Template.new(:program_id => program.id, source: "Test", subject: "Test")
    email_template.belongs_to_cm = true

    assert_equal 2, uc.statuses.count
    assert_no_difference 'CampaignManagement::UserCampaignMessageJob.count' do
      assert_no_difference 'CampaignManagement::UserCampaignStatus.count' do
        campaign.campaign_messages.create!(:sender_id => programs(:albers).admin_users.first.id, :email_template => email_template, :duration => 5)
      end
    end
  end

end
