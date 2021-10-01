require_relative './../../../../test_helper'

class SurveyQuestionExporterTest < ActiveSupport::TestCase

  def test_survey_question_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    se = SurveyExporter.new(program, program_exporter)
    sqe = SurveyQuestionExporter.new(program, se)
    sqe.export

    surveys = program.surveys
    surveyQuestions = surveys.map{|survey| survey.survey_questions_with_matrix_rating_questions}.flatten

    exported_survey_question_ids = []

    assert_equal sqe.file_name, 'survey_question_survey'
    assert_equal sqe.parent_exporter, se
    assert_equal sqe.program, program

    surveyQuestionsFilePath = solution_pack.base_path + 'survey_question_survey.csv'
    assert File.exist?(surveyQuestionsFilePath)
    CSV.foreach(surveyQuestionsFilePath, headers: true) do |row|
      exported_survey_question_ids << row["id"].to_i
    end

    assert_equal_unordered exported_survey_question_ids, surveyQuestions.collect(&:id)

    File.delete(surveyQuestionsFilePath)
  end

  def test_ensure_survey_question_model_unchanged
    expected_attribute_names = ["id", "program_id", "question_text", "question_type", "question_info", "position", "created_at", "updated_at", "required", "help_text", "type", "survey_id", "common_answers_count", "feedback_form_id", "allow_other_option", "is_admin_only", "question_mode", "positive_outcome_options", "matrix_position", "matrix_setting", "matrix_question_id", "condition", "positive_outcome_options_management_report"]
    assert_equal_unordered expected_attribute_names, SurveyQuestion.attribute_names

    survey_question_column_hash = SurveyQuestion.columns_hash
    survey_question_translation_column_hash = SurveyQuestion::Translation.columns_hash
    assert_equal survey_question_column_hash["program_id"].type, :integer
    assert_equal :text, survey_question_translation_column_hash["question_text"].type
    assert_equal survey_question_column_hash["question_type"].type, :integer
    assert_equal :text, survey_question_translation_column_hash["question_info"].type
    assert_equal survey_question_column_hash["position"].type, :integer
    assert_equal survey_question_column_hash["created_at"].type, :datetime
    assert_equal survey_question_column_hash["updated_at"].type, :datetime
    assert_equal survey_question_column_hash["required"].type, :boolean
    assert_equal :text, survey_question_translation_column_hash["help_text"].type
    assert_equal survey_question_column_hash["type"].type, :string
    assert_equal survey_question_column_hash["survey_id"].type, :integer
    assert_equal survey_question_column_hash["common_answers_count"].type, :integer
    assert_equal survey_question_column_hash["feedback_form_id"].type, :integer
    assert_equal survey_question_column_hash["allow_other_option"].type, :boolean
    assert_equal survey_question_column_hash["is_admin_only"].type, :boolean
    assert_equal survey_question_column_hash["question_mode"].type, :integer
    assert_equal survey_question_column_hash["positive_outcome_options"].type, :text
    assert_equal survey_question_column_hash["matrix_position"].type, :integer
    assert_equal survey_question_column_hash["matrix_setting"].type, :integer
    assert_equal survey_question_column_hash["matrix_question_id"].type, :integer
    assert_equal survey_question_column_hash["condition"].type, :integer
    assert_equal survey_question_column_hash["positive_outcome_options_management_report"].type, :text
  end
end