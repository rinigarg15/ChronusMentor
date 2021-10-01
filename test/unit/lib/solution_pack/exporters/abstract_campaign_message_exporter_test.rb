require_relative './../../../../test_helper.rb'

class AbstractCampaignMessageExporterTest < ActiveSupport::TestCase

  def test_campaign_message_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    campaign_exporter = AbstractCampaignExporter.new(program, program_exporter)
    MailerTemplateExporter.any_instance.expects(:export)
    campaign_message_exporter = AbstractCampaignMessageExporter.new(program, campaign_exporter)
    campaign_message_exporter.export

    campaigns = program.abstract_campaigns
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where("campaign_id IN (?)", campaigns.collect(&:id))
    exported_campaign_message_ids = []

    assert_equal campaign_message_exporter.objs, campaign_messages
    assert_equal campaign_message_exporter.file_name, 'campaign_message'
    assert_equal campaign_message_exporter.program, program
    assert_equal campaign_message_exporter.parent_exporter, campaign_exporter

    assert File.exist?(solution_pack.base_path+'campaign_message.csv')
    CSV.foreach(solution_pack.base_path+'campaign_message.csv', headers: true) do |row|
      exported_campaign_message_ids << row["id"].to_i
    end
    assert_equal_unordered exported_campaign_message_ids, campaign_messages.collect(&:id)

    File.delete(solution_pack.base_path+'campaign_message.csv') if File.exist?(solution_pack.base_path+'campaign_message.csv')
  end

  def test_campaign_message_model_unchanged
    expected_attribute_names = ["id", "campaign_id", "sender_id", "duration", "created_at", "updated_at", "user_jobs_created", "type"]
    assert_equal_unordered expected_attribute_names, CampaignManagement::AbstractCampaignMessage.attribute_names
  end
end