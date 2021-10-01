require_relative './../../../../test_helper.rb'

class CondtionalMatchChoiceImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_condtional_match_choice_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    new_program.admin_views.destroy_all
    new_program.abstract_campaigns.destroy_all
    new_program.surveys.destroy_all

    include_importers(:settings, :forum, :mentoring_model, :resource, :group_closure_reason, :overview_pages)

    solution_pack = SolutionPack.new(program: new_program, created_by: "test admin", description: "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    ProgramImporter.new(solution_pack).import

    new_program.reload

    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question")
    assert_equal ["Male"], profile_question.conditional_text_choices

    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Gender")
    assert_equal ["Wireless"], profile_question.conditional_text_choices

    conditional_match_choice_imported_file_path = File.join(solution_pack.base_directory_path, "conditional_match_choice-imported.csv")
    assert File.exist?(conditional_match_choice_imported_file_path)
  end

  def test_handle_object_creation_with_duplicate_question
    program = programs(:albers)
    profile_question = profile_questions(:profile_questions_1)

    solution_pack = SolutionPack.new(program: program, created_by: "test admin", description: "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    conditional_match_choice_importer = ConditionalMatchChoiceImporter.new(program_importer)

    conditional_question = profile_questions(:profile_questions_9)
    profile_question.update_attribute(:conditional_question_id, conditional_question.id)

    new_conditional_match_choice = profile_question.conditional_match_choices.new(question_choice_id: conditional_question.question_choice_ids[0])
    assert_difference "ConditionalMatchChoice.count", 1 do
      conditional_match_choice_importer.handle_object_creation(new_conditional_match_choice, 1, [], "")
    end

    new_conditional_match_choice.reload

    assert_no_difference "ConditionalMatchChoice.count" do
      conditional_match_choice_importer.handle_object_creation(new_conditional_match_choice, 1, [], "")
    end

    profile_question = profile_questions(:profile_questions_2)
    conditional_question = profile_questions(:profile_questions_9)
    profile_question.update_attribute(:conditional_question_id, nil)
    new_conditional_match_choice = profile_question.conditional_match_choices.new(question_choice_id: conditional_question.question_choice_ids[0])
    assert_no_difference "ConditionalMatchChoice.count" do
      conditional_match_choice_importer.handle_object_creation(new_conditional_match_choice, 1, [], "")
    end
  end
end