require_relative './../../../../test_helper.rb'

class MatchConfigExporterTest < ActiveSupport::TestCase

  def test_match_config_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    role_question_exporter = RoleQuestionExporter.new(program, profile_question_exporter)
    match_config_exporter = MatchConfigExporter.new(program, role_question_exporter)
    match_config_exporter.export

    match_configs = program.match_configs
    exported_match_config_ids = []

    assert_equal match_config_exporter.objs, match_configs
    assert_equal match_config_exporter.file_name, 'match_config'
    assert_equal match_config_exporter.program, program
    assert_equal match_config_exporter.parent_exporter, role_question_exporter

    match_config_file_path = solution_pack.base_path+'match_config.csv'
    assert File.exist?(match_config_file_path)
    CSV.foreach(match_config_file_path, headers: true) do |row|
      exported_match_config_ids << row["id"].to_i
    end
    assert_equal_unordered exported_match_config_ids, match_configs.collect(&:id)

    File.delete(match_config_file_path) if File.exist?(match_config_file_path)
  end

  def test_match_config_model_unchanged
    expected_attribute_names = ["id", "mentor_question_id", "student_question_id", "program_id", "weight", "created_at", "updated_at", "threshold", "operator", "matching_type", "matching_details_for_display", "matching_details_for_matching", "show_match_label", "prefix"]
    assert_equal_unordered expected_attribute_names, MatchConfig.attribute_names
  end
end