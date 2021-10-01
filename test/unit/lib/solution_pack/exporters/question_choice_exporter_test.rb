require_relative './../../../../test_helper.rb'

class QuestionChoiceExporterTest < ActiveSupport::TestCase

  def test_question_choice_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    question_choice_exporter = QuestionChoiceExporter.new(program, profile_question_exporter)
    question_choice_exporter.export

    profile_question_ids = program.role_questions.includes(:profile_question).collect(&:profile_question).uniq.collect(&:id)
    question_choices = QuestionChoice.where(ref_obj_id: profile_question_ids, ref_obj_type: ProfileQuestion.name).to_a

    exported_question_choice_ids = []

    assert_equal_unordered question_choice_exporter.objs, question_choices
    assert_equal question_choice_exporter.file_name, 'question_choice_profile_question'
    assert_equal question_choice_exporter.program, program
    assert_equal question_choice_exporter.parent_exporter, profile_question_exporter

    assert File.exist?(solution_pack.base_path+'question_choice_profile_question.csv')
    CSV.foreach(solution_pack.base_path+'question_choice_profile_question.csv', headers: true) do |row|
      exported_question_choice_ids << row["id"].to_i
    end
    assert_equal_unordered exported_question_choice_ids, question_choices.collect(&:id)
    File.delete(solution_pack.base_path+'question_choice_profile_question.csv') if File.exist?(solution_pack.base_path+'question_choice_profile_question.csv')
  end

  def test_question_choice_model_unchanged
    expected_attribute_names = ["id", "text", "is_other", "position", "ref_obj_id", "ref_obj_type", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, QuestionChoice.attribute_names
  end
end