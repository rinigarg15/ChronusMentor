require_relative './../test_helper'

class CampaignManagement::ExporterTest < ActiveSupport::TestCase

  attr_accessor :campaign_template_rows, :campaign_message_template_rows
  include CampaignManagement::ImportExportUtils
  include ImportExportUtils

  ITEM_TO_DATA_MODULE_MAPPER = {
    campaign_template: CampaignManagement::ImportExportUtils::CampaignTemplate,
    campaign_message_template: CampaignManagement::ImportExportUtils::CampaignMessageTemplate
  }

  def test_export_file
    program = programs(:albers)
    cms = program.user_campaigns.first(3)
    cms[0].update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::ACTIVE)
    cms[1].update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::STOPPED)
    cms[2].update_attribute(:state, CampaignManagement::AbstractCampaign::STATE::DRAFTED)
    csv_exporter = CampaignManagement::Exporter.new.export(program.id)
    data = CSV.parse(csv_exporter)
    items_header = [:campaign_template, :campaign_message_template]
    extract_data_rows_from_csv_data(self, data, ITEM_TO_DATA_MODULE_MAPPER, items_header)

    campaigns = []
    campaign_states = []
    campaign_messages_duration = []
    emails_subject = []

    campaign_template_rows.each do |cm|
      campaigns << cm.first
      campaign_states << cm[2]
    end

    campaign_message_template_rows.each do |cm_message|
      emails_subject << cm_message[0]
      campaign_messages_duration << cm_message[2]
    end

    assert_equal ["yes", "no", "draft"], campaign_states.first(3)
    assert_equal ["Get users to sign up", "Get users to complete profiles", "Campaign1 Name", "Campaign2 Name", "Campaign4 Name", "Campaign5 Name", "Disabled Campaign-3 Name", "Disabled Campaign4 Name"], campaigns
    assert_equal ["7", "30", "0", "5", "10", "15", "4", "6", "0", "0"], campaign_messages_duration
    assert_equal ["{{user_firstname}}, finish signing up today!", "{{user_firstname}}, complete your profile today!", "Campaign Message - Subject1", "Campaign Message - Subject2", "Campaign Message - Subject3", "Campaign Message - Subject4", "Campaign Message - Subject7", "Campaign Message - Subject8", "Campaign Message - Subject5", "Campaign Message - Subject6"], emails_subject
  end
end