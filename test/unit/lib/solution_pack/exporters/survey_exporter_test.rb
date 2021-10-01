require_relative './../../../../test_helper'

class SurveyExporterTest < ActiveSupport::TestCase

  def test_survey_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    se = SurveyExporter.new(program, program_exporter)
    se.export

    surveys = program.surveys
    surveyQuestions = surveys.map{|survey| survey.survey_questions_with_matrix_rating_questions}.flatten
    roleRefs = RoleReference.joins(:role).where(roles: { program_id: program.id }).select{|rr| rr.ref_obj_type == "Survey"}
    exported_survey_ids = []
    exported_survey_question_ids = []
    exported_role_refs = []

    assert_equal se.parent_exporter, program_exporter
    assert_equal se.program, program
    assert_equal se.file_name, 'survey'

    surveyFilePath = solution_pack.base_path+'survey.csv'
    assert File.exist?(surveyFilePath)
    CSV.foreach(surveyFilePath, headers: true) do |row|
      exported_survey_ids << row["id"].to_i
    end

    surveyQuestionsFilePath = solution_pack.base_path+'survey_question_survey.csv'
    assert File.exist?(surveyQuestionsFilePath)
    CSV.foreach(surveyQuestionsFilePath, headers: true) do |row|
      exported_survey_question_ids << row["id"].to_i
    end

    roleRefsFilePath = solution_pack.base_path + 'role_reference_survey.csv'
    assert File.exist?(roleRefsFilePath)
    CSV.foreach(roleRefsFilePath, headers: true) do |row|
      exported_role_refs << row["id"].to_i
    end

    assert_equal_unordered exported_survey_ids, surveys.collect(&:id)
    assert_equal_unordered exported_survey_question_ids, surveyQuestions.collect(&:id)
    assert_equal_unordered exported_role_refs, roleRefs.collect(&:id)

    File.delete(surveyFilePath)
    File.delete(surveyQuestionsFilePath)
    File.delete(roleRefsFilePath)
  end

  def test_ensure_survey_model_unchanged
    expected_attribute_names = ["id", "program_id", "name", "due_date", "created_at", "updated_at", "total_responses", "type", "edit_mode", "form_type", "role_name", "progress_report"]
    assert_equal_unordered expected_attribute_names, Survey.attribute_names

    survey_column_hash = Survey.columns_hash
    survey_translation_column_hash = Survey::Translation.columns_hash
    assert_equal survey_column_hash["program_id"].type, :integer
    assert_equal :string, survey_translation_column_hash["name"].type
    assert_equal survey_column_hash["due_date"].type, :date
    assert_equal survey_column_hash["created_at"].type, :datetime
    assert_equal survey_column_hash["updated_at"].type, :datetime
    assert_equal survey_column_hash["total_responses"].type, :integer
    assert_equal survey_column_hash["type"].type, :string
    assert_equal survey_column_hash["edit_mode"].type, :integer
    assert_equal survey_column_hash["form_type"].type, :integer
  end
end