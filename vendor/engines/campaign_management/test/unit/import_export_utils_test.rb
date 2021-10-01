require_relative './../test_helper'

class CampaignManagement::ImportExportUtilsTest < ActiveSupport::TestCase

  def test_campaign_template_constants
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::BLOCK_IDENTIFIER, '#Campaign'
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::HEADER, ["Name", "AdminView", "Enable", "Type"]
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::FIELD_HEADER_ORDER, [:title, :trigger_params, :state, :type]

    program = programs(:albers)
    options = { campaign_referenced_by_title: {}, program_id: program.id }
    all_users_view_id = program.admin_views.find_by(default_view: AbstractView::DefaultType::ALL_USERS).id
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::DATA_INTERPRETOR[:trigger_params].call("All Users", options), { 1 => [all_users_view_id] }
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::DATA_INTERPRETOR[:state].call("yes", options), 0
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::DATA_INTERPRETOR[:state].call("no", options), 1
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::DATA_INTERPRETOR[:state].call("draft", options), 2
    assert_equal CampaignManagement::ImportExportUtils::CampaignTemplate::DATA_INTERPRETOR[:type].call("ProgramInvitation", options), "CampaignManagement::ProgramInvitationCampaign"
  end

  def test_campaign_message_template_constants
    assert_equal CampaignManagement::ImportExportUtils::CampaignMessageTemplate::BLOCK_IDENTIFIER, '#Emails'
    assert_equal CampaignManagement::ImportExportUtils::CampaignMessageTemplate::HEADER, ["Subject", "Message", "Schedule", "Campaign"]
    assert_equal CampaignManagement::ImportExportUtils::CampaignMessageTemplate::FIELD_HEADER_ORDER, [:subject, :source, :duration, :campaign_id]

    options = { campaign_referenced_by_title: { "Campaign1 Name" => CampaignManagement::AbstractCampaign.first }, program_id: programs(:albers).id }
    assert_equal 0, CampaignManagement::ImportExportUtils::CampaignMessageTemplate::DATA_INTERPRETOR[:duration].call("0", options)
    assert_equal 1, CampaignManagement::ImportExportUtils::CampaignMessageTemplate::DATA_INTERPRETOR[:campaign_id].call("Campaign1 Name", options)
  end
end