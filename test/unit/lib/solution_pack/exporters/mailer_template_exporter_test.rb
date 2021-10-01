require_relative './../../../../test_helper.rb'

class MailerTemplateExporterTest < ActiveSupport::TestCase

  def test_mailer_template_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    campaign_exporter = AbstractCampaignExporter.new(program, program_exporter)
    campaign_message_exporter = AbstractCampaignMessageExporter.new(program, campaign_exporter)
    mailer_template_exporter = MailerTemplateExporter.new(program, campaign_message_exporter)
    mailer_template_exporter.export

    campaigns = program.abstract_campaigns
    campaign_messages = CampaignManagement::AbstractCampaignMessage.where("campaign_id IN (?)", campaigns.collect(&:id))
    mailer_templates = Mailer::Template.where("campaign_message_id IN (?)", campaign_messages.collect(&:id))
    exported_mailer_template_ids = []

    assert_equal mailer_template_exporter.objs, mailer_templates
    assert_equal mailer_template_exporter.file_name, 'mailer_template_campaign_message'
    assert_equal mailer_template_exporter.program, program
    assert_equal mailer_template_exporter.parent_exporter, campaign_message_exporter

    assert File.exist?(solution_pack.base_path+'mailer_template_campaign_message.csv')
    CSV.foreach(solution_pack.base_path+'mailer_template_campaign_message.csv', headers: true) do |row|
      exported_mailer_template_ids << row["id"].to_i
    end
    assert_equal_unordered exported_mailer_template_ids, mailer_templates.collect(&:id)

    File.delete(solution_pack.base_path+'mailer_template_campaign_message.csv') if File.exist?(solution_pack.base_path+'mailer_template_campaign_message.csv')
  end

  def test_mailer_template_export_with_non_campaign_mails
    program = programs(:albers)
    mailer_template = Mailer::Template.new(:program => programs(:albers), uid: '284oda1i')
    mailer_template.save
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    mailer_template_exporter = MailerTemplateExporter.new(program, program_exporter)
    mailer_template_exporter.export

    mailer_templates = program.mailer_templates.where("campaign_message_id is NULL")
    exported_mailer_template_ids = []

    assert_equal mailer_template_exporter.objs, mailer_templates
    assert_equal mailer_template_exporter.file_name, 'mailer_template'
    assert_equal mailer_template_exporter.program, program
    assert_equal mailer_template_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'mailer_template.csv')
    CSV.foreach(solution_pack.base_path+'mailer_template.csv', headers: true) do |row|
      exported_mailer_template_ids << row["id"].to_i
    end
    assert_equal_unordered exported_mailer_template_ids, mailer_templates.collect(&:id)

    File.delete(solution_pack.base_path+'mailer_template.csv') if File.exist?(solution_pack.base_path+'mailer_template.csv')
  end

  def test_mailer_template_model_unchanged
    expected_attribute_names = ["id", "program_id", "uid", "enabled", "source", "subject", "created_at", "updated_at", "campaign_message_id", "copied_content", "content_changer_member_id", "content_updated_at"]
    assert_equal_unordered expected_attribute_names, Mailer::Template.attribute_names
  end
end