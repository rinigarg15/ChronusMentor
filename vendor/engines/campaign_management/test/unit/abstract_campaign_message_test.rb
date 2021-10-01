require_relative './../test_helper'

class CampaignMessageTest < ActiveSupport::TestCase
  def test_belongs_to_campaign
    assert_equal cm_campaigns(:active_campaign_1), cm_campaign_messages(:campaign_message_1).campaign
  end

  def test_presence_of_type_in_campaign_message
    cm = cm_campaign_messages(:campaign_message_1)
    cm.type = nil
    cm.save
    assert_equal_unordered ["can't be blank", "is not included in the list"], cm.errors[:type]
  end

  def test_presence_of_type_in_the_list
    cm = cm_campaign_messages(:campaign_message_1)
    cm.type = "invalid campaign type"
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :type, "is not included in the list" do
      cm.save!
    end
  end

  def test_has_one_email_template
    cm_campaign_messages(:campaign_message_1).email_template.destroy
    mailer = Mailer::Template.create!(:program => programs(:albers), :uid => AdminWeeklyStatus.mailer_attributes[:uid], :campaign_message_id => cm_campaign_messages(:campaign_message_1).id, source: "Source", subject: "Subject")
    mailer.save!
    assert_equal mailer, cm_campaign_messages(:campaign_message_1).reload.email_template
    assert_difference "Mailer::Template.count", -1 do
      cm_campaign_messages(:campaign_message_1).destroy
    end
  end

  def test_presence_of_sender
    campaign_message = cm_campaign_messages(:campaign_message_1)
    assert_nothing_raised do
      campaign_message.update_attributes!(sender_id: nil)
    end
  end

  def test_presence_of_duration
    campaign_message = cm_campaign_messages(:campaign_message_1)
    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "is not a number" do
      campaign_message.update_attributes!(duration: nil)
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "is not a number" do
      campaign_message.update_attributes!(duration: "Test")
    end

    assert_raise_error_on_field ActiveRecord::RecordInvalid, :duration, "must be greater than or equal to 0" do
      campaign_message.update_attributes!(duration: "-1")
    end
  end

  def test_duration_should_be_without_higher_limit
    campaign_message = cm_campaign_messages(:campaign_message_1)
    campaign_message.update_attributes!(duration: "1000000")
    assert_equal campaign_message.duration, 1000000
  end

  def test_default_duration_should_be_zero
    campaign = cm_campaigns(:active_campaign_1)
    email_template = Mailer::Template.new(:program_id => programs(:albers).id)
    email_template.belongs_to_cm = true
    cm = CampaignManagement::UserCampaignMessage.new(:sender_id => programs(:albers).admin_users.first.id, :email_template => email_template)
    cm.campaign_id = campaign.id
    cm.save!
    assert_equal 0, cm.duration
  end

  def test_get_analytics_summary_key_should_return_the_right_key
    time = Time.new(2002,10)
    assert_equal "200210", CampaignManagement::AbstractCampaignMessage.get_analytics_summary_key(time)
  end

  def test_reset_sender_id_for
    user = users(:f_admin)
    messages = CampaignManagement::AbstractCampaignMessage.where(sender_id: user.id).all
    CampaignManagement::AbstractCampaignMessage.reset_sender_id_for(user.id)
    messages.each do |message|
      assert_nil message.reload.sender_id
    end
  end

  def test_replace_mustaches_with_delimiters
    campaign_message = cm_campaign_messages(:campaign_message_1)
    campaign_message.email_template.update_attributes(:subject => "Welcome {{user_name}}", :source => "Dear {{user_lastname}}")
    subject, body = campaign_message.replace_mustache_with_mailgun_delimiters([:user_lastname, :user_name, :widget_styles])
    assert_equal "Welcome %recipient.user_name%", subject
    assert_equal "Dear %recipient.user_lastname%%recipient.widget_styles%", body
  end

  def test_mail_sender_name_when_admin_is_configured
    campaign_message = cm_campaign_messages(:campaign_message_1)
    assert_equal "Freakin Admin via Albers Mentor Program", campaign_message.mail_sender_name
  end

  def test_mail_sender_name_when_program_name_is_configured
    campaign_message = cm_campaign_messages(:campaign_message_1)
    campaign_message.update_attributes(:sender_id => nil)
    assert_equal "Albers Mentor Program", campaign_message.mail_sender_name
  end

  def test_handle_schedule_update
    time_now = Time.now
    campaign_message = cm_campaign_messages(:campaign_message_1)
    CampaignManagement::UserCampaignMessage.any_instance.expects(:update_jobs_timing).once
    CampaignManagement::UserCampaignMessage.any_instance.expects(:create_jobs_for_eligible_statuses).with(time_now).once
    campaign_message.handle_schedule_update(time_now)

    campaign_message = surveys(:two).campaign.campaign_messages.first
    campaign_message.expects(:handle_schedule_update_for_survey_campaign).with(time_now).once
    campaign_message.expects(:update_jobs_timing).never
    campaign_message.expects(:create_jobs_for_eligible_statuses).never
    campaign_message.handle_schedule_update(time_now)
  end

  def test_update_jobs_timing_for_campaign_message_whose_duration_changed
    campaign_message = cm_campaign_messages(:campaign_message_1)
    campaign_message.update_attributes(duration: 4)

    user_jobs = CampaignManagement::UserCampaignMessageJob.where(campaign_message_id: campaign_message.id)

    user_jobs.each do |user_job|
      assert_equal user_job.run_at, CampaignManagement::UserCampaignStatus.where(:campaign_id => campaign_message.campaign.id, :abstract_object_id => user_job.abstract_object_id).first.started_at + campaign_message.duration.days
    end
  end

end
