require_relative './../../../../test_helper.rb'

class ConditionalMatchChoiceExporterTest < ActiveSupport::TestCase

  def test_conditional_match_choice_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(program: program, created_by: "need")
    conditional_question = profile_questions(:profile_questions_9)
    pq = profile_questions(:profile_questions_10)
    pq.conditional_question_id = conditional_question.id
    pq.save!

    conditional_match_choices = pq.conditional_match_choices.create!(question_choice_id: conditional_question.question_choice_ids[0])
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    conditional_match_choice_exporter = ConditionalMatchChoiceExporter.new(program, profile_question_exporter)
    conditional_match_choice_exporter.export

    exported_question_choice_ids = []

    assert_equal_unordered conditional_match_choice_exporter.objs, [conditional_match_choices]
    assert_equal conditional_match_choice_exporter.file_name, 'conditional_match_choice'
    assert_equal conditional_match_choice_exporter.program, program
    assert_equal conditional_match_choice_exporter.parent_exporter, profile_question_exporter

    assert File.exist?(solution_pack.base_path+'conditional_match_choice.csv')
    CSV.foreach(solution_pack.base_path+'conditional_match_choice.csv', headers: true) do |row|
      exported_question_choice_ids << row["id"].to_i
    end
    assert_equal_unordered exported_question_choice_ids, [conditional_match_choices].collect(&:id)
    File.delete(solution_pack.base_path+'conditional_match_choice.csv') if File.exist?(solution_pack.base_path+'conditional_match_choice.csv')
  end

  def test_conditional_match_choice_model_unchanged
    expected_attribute_names = ["id", "question_choice_id", "profile_question_id", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, ConditionalMatchChoice.attribute_names
  end
end