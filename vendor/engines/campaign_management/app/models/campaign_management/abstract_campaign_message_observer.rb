class CampaignManagement::AbstractCampaignMessageObserver < ActiveRecord::Observer
  def after_create(campaign_message)
    unless campaign_message.campaign.is_user_campaign?
      campaign_message.create_jobs_for_newly_created_campaign_message(Time.zone.now)
    end
  end

  def after_update(campaign_message)
    return if campaign_message.skip_observer
    process_duration_changes(campaign_message) if campaign_message.saved_change_to_duration? && campaign_message.user_jobs_created
  end

  def before_save(campaign_message)
    email_template = campaign_message.email_template
    email_template.belongs_to_cm = true
    return unless email_template.is_campaign_message_template_being_created_now?
    email_template.validate_tags_and_widgets_through_campaign(campaign_message.campaign_id)
  end

  private

  def process_duration_changes(campaign_message)
    campaign_message.delay.handle_schedule_update(Time.zone.now)
  end

end