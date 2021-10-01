class CampaignManagement::Exporter

  include ImportExportUtils

  def export(current_program_id)
    campaigns = CampaignManagement::UserCampaign
    CSV.send(*[:generate]) do |csv|
      if campaigns.present?
        csv << [CampaignManagement::ImportExportUtils::CampaignTemplate::BLOCK_IDENTIFIER]
        csv << CampaignManagement::ImportExportUtils::CampaignTemplate::HEADER
        campaigns.where(:program_id => current_program_id).each do |campaign|
          csv_header = campaign_template_csv_content(campaign)
          csv << csv_header
        end
        csv << []

        csv << [CampaignManagement::ImportExportUtils::CampaignMessageTemplate::BLOCK_IDENTIFIER]
        csv << CampaignManagement::ImportExportUtils::CampaignMessageTemplate::HEADER
        campaigns.where(:program_id => current_program_id).each do |campaign|
          campaign.campaign_messages.each do |campaign_message|
            csv_header = email_template_csv_content(campaign_message, current_program_id)
            csv << csv_header
          end
        end
      end
    end
  end

  private

  def campaign_template_csv_content(campaign)

    title = campaign.title
    admin_view = campaign.trigger_params.nil? ? "" : AdminView.find(campaign.trigger_params[1].first).title
    state = get_state(campaign.state)

    [title, admin_view, state]
  end

  def get_state(state)
    case state
    when CampaignManagement::AbstractCampaign::STATE::ACTIVE
      "yes"
    when CampaignManagement::AbstractCampaign::STATE::STOPPED
      "no"
    when CampaignManagement::AbstractCampaign::STATE::DRAFTED
      "draft"
    end
  end

  def email_template_csv_content(campaign_message, current_program_id)

    subject = campaign_message.email_template.subject
    source = campaign_message.email_template.source
    duration = campaign_message.duration
    campaign_title = campaign_message.campaign.title

    [subject, source, duration, campaign_title]
  end
end
