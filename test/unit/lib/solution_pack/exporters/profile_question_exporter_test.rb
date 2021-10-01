require_relative './../../../../test_helper.rb'

class ProfileQuestionExporterTest < ActiveSupport::TestCase

  def test_profile_question_export
    pq = create_question(:question_type => ProfileQuestion::Type::STRING, :question_text => "Whats your age?", :program => programs(:nwen))
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    profile_question_exporter = ProfileQuestionExporter.new(program, program_exporter)
    profile_question_exporter.export

    profile_questions = program.role_questions.includes(:profile_question).collect(&:profile_question).uniq
    exported_profile_question_ids = []

    assert_equal_unordered profile_question_exporter.objs, profile_questions
    assert_equal profile_question_exporter.file_name, 'profile_question'
    assert_equal profile_question_exporter.program, program
    assert_equal profile_question_exporter.parent_exporter, program_exporter

    assert File.exist?(solution_pack.base_path+'profile_question.csv')
    assert File.exist?(solution_pack.base_path+'role_question.csv')
    assert File.exist?(solution_pack.base_path+'question_choice_profile_question.csv')
    assert File.exist?(solution_pack.base_path+'conditional_match_choice.csv')
    CSV.foreach(solution_pack.base_path+'profile_question.csv', headers: true) do |row|
      exported_profile_question_ids << row["id"].to_i
    end
    assert_equal_unordered exported_profile_question_ids, profile_questions.collect(&:id)
    assert_false exported_profile_question_ids.include?(pq.id)
    File.delete(solution_pack.base_path+'profile_question.csv') if File.exist?(solution_pack.base_path+'profile_question.csv')
    File.delete(solution_pack.base_path+'role_question.csv') if File.exist?(solution_pack.base_path+'role_question.csv')
    File.delete(solution_pack.base_path+'question_choice_profile_question.csv') if File.exist?(solution_pack.base_path+'question_choice_profile_question.csv')
    File.delete(solution_pack.base_path+'conditional_match_choice.csv') if File.exist?(solution_pack.base_path+'conditional_match_choice.csv')
  end

  def test_profile_question_model_unchanged
    expected_attribute_names = ["id", "organization_id", "question_text", "question_type", "question_info", "position", "section_id", "help_text", "profile_answers_count", "created_at", "updated_at", "allow_other_option", "options_count", "conditional_question_id", "conditional_match_text", "text_only_option"]
    assert_equal_unordered expected_attribute_names, ProfileQuestion.attribute_names
  end
end