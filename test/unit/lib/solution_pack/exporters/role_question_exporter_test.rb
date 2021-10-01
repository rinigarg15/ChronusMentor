require_relative './../../../../test_helper.rb'

class RoleQuestionExporterTest < ActiveSupport::TestCase

  def test_role_question_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    exported_role_question_ids = []

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    role_question_exporter = RoleQuestionExporter.new(program, profile_question_exporter)
    role_question_exporter.export

    assert_equal_unordered role_question_exporter.objs, program.role_questions
    assert_equal role_question_exporter.file_name, 'role_question'
    assert_equal role_question_exporter.program, program
    assert_equal role_question_exporter.parent_exporter, profile_question_exporter

    assert File.exist?(solution_pack.base_path+'role_question.csv')
    CSV.foreach(solution_pack.base_path+'role_question.csv', headers: true) do |row|
      exported_role_question_ids << row["id"].to_i
    end

    assert_equal_unordered exported_role_question_ids, program.role_questions.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end

  def test_role_question_model_unchanged
    expected_attribute_names = ["id", "role_id", "required", "private", "filterable", "profile_question_id", "created_at", "updated_at", "in_summary", "available_for", "admin_only_editable"]
    assert_equal_unordered expected_attribute_names, RoleQuestion.attribute_names
  end

  def test_role_question_export_for_portal
    program = programs(:primary_portal)
    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).returns(1234)
    exported_role_question_ids = []

    MatchConfigExporter.any_instance.expects(:export).never

    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    role_question_exporter = RoleQuestionExporter.new(program, profile_question_exporter)
    role_question_exporter.export

    assert_equal_unordered role_question_exporter.objs, program.role_questions
    assert_equal role_question_exporter.file_name, 'role_question'
    assert_equal role_question_exporter.program, program
    assert_equal role_question_exporter.parent_exporter, profile_question_exporter

    assert File.exist?(solution_pack.base_path+'role_question.csv')
    CSV.foreach(solution_pack.base_path+'role_question.csv', headers: true) do |row|
      exported_role_question_ids << row["id"].to_i
    end

    assert_equal_unordered exported_role_question_ids, program.role_questions.collect(&:id)

    FileUtils.rm_rf(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s+SP_BASE_PATH_FOR_EXPORT_TEST)
  end
end