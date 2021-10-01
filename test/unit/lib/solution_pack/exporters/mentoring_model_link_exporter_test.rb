require_relative './../../../../test_helper.rb'

class MentoringModelLinkExporterTest < ActiveSupport::TestCase

  def test_mentoring_model_link_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    mentoring_model_exporter = MentoringModelExporter.new(program, program_exporter)
    mentoring_model_link_exporter = MentoringModelLinkExporter.new(program, mentoring_model_exporter)
    mentoring_model_link_exporter.export

    mentoring_models = program.mentoring_models
    mentoring_model_links = MentoringModel::Link.where("child_template_id IN (?) AND parent_template_id IN (?)", mentoring_models.collect(&:id), mentoring_models.collect(&:id))
    exported_mentoring_model_link_ids = []

    assert_equal mentoring_model_link_exporter.program, program
    assert_equal mentoring_model_link_exporter.file_name, 'mentoring_model_link'
    assert_equal mentoring_model_link_exporter.objs, mentoring_model_links
    assert_equal mentoring_model_link_exporter.parent_exporter, mentoring_model_exporter

    assert File.exist?(solution_pack.base_path+'mentoring_model_link.csv')
    CSV.foreach(solution_pack.base_path+'mentoring_model_link.csv', headers: true) do |row|
      exporter_mentoring_model_link_ids << row["id"].to_i
    end
    assert_equal_unordered exported_mentoring_model_link_ids, mentoring_model_links.collect(&:id)

    File.delete(solution_pack.base_path+'mentoring_model_link.csv') if File.exist?(solution_pack.base_path+'mentoring_model_link.csv')
  end

  def test_mentoring_model_link_columns_unchanged
    expected_attribute_names = ["id", "child_template_id", "parent_template_id", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, MentoringModel::Link.attribute_names
  end
end