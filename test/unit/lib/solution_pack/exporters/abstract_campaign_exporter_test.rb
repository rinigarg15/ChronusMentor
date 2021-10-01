require_relative './../../../../test_helper.rb'

class AbstractCampaignExporterTest < ActiveSupport::TestCase

  def test_campaign_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    AbstractCampaignMessageExporter.any_instance.expects(:export)
    campaign_exporter = AbstractCampaignExporter.new(program, program_exporter)
    campaign_exporter.export

    campaigns = program.abstract_campaigns
    exported_campaign_ids = []

    assert_equal campaign_exporter.objs, campaigns
    assert_equal campaign_exporter.file_name, 'campaign'
    assert_equal campaign_exporter.program, program
    assert_equal campaign_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'campaign.csv')
    CSV.foreach(solution_pack.base_path+'campaign.csv', headers: true) do |row|
      exported_campaign_ids << row["id"].to_i
    end
    assert_equal_unordered exported_campaign_ids, campaigns.collect(&:id)

    File.delete(solution_pack.base_path+'campaign.csv') if File.exist?(solution_pack.base_path+'campaign.csv')
  end

  def test_campaign_model_unchanged
    expected_attribute_names = ["id", "program_id", "title", "state", "trigger_params", "created_at", "updated_at", "type", "featured", "enabled_at", "ref_obj_id"]
    assert_equal_unordered expected_attribute_names, CampaignManagement::AbstractCampaign.attribute_names
  end
end