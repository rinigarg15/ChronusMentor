require_relative './../../../../test_helper.rb'

class QuestionChoiceImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_question_choice_import
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

    profile_question_choice_texts = []
    profile_question_choice_file_path = File.join(IMPORT_CSV_BASE_PATH, "question_choice_profile_question.csv")
    profile_question_csv_content = fixture_file_upload(profile_question_choice_file_path, "text/csv")

    survey_question_choice_texts = []
    survey_question_choice_file_path = File.join(IMPORT_CSV_BASE_PATH, "question_choice_survey_question_survey.csv")
    survey_question_csv_content = fixture_file_upload(survey_question_choice_file_path, "text/csv")

    survey_question_csv = CSV.parse(survey_question_csv_content, :headers => true)
    survey_question_csv.each do |row|
      survey_question_choice_texts << row["text"]
    end

    profile_question_csv = CSV.parse(profile_question_csv_content, :headers => true)
    profile_question_csv.each do |row|
      profile_question_choice_texts << row["text"]
    end


    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_profile_question_choice_texts = QuestionChoice.where(ref_obj_id: new_program.organization.profile_questions_with_email_and_name.pluck(:id), ref_obj_type: ProfileQuestion.name).map(&:text)
    imported_survey_question_choice_texts = QuestionChoice.where(ref_obj_id: new_program.survey_question_ids, ref_obj_type: CommonQuestion.name).map(&:text)

    profile_question_choice_texts.each do |text|
      assert imported_profile_question_choice_texts.include?(text)
    end

    survey_question_choice_texts.each do |text|
      assert imported_survey_question_choice_texts.include?(text)
    end

    profile_question_choice_imported_file_path = File.join(solution_pack.base_directory_path, "question_choice_profile_question-imported.csv")
    assert File.exist?(profile_question_choice_imported_file_path)

    survey_question_choice_imported_file_path = File.join(solution_pack.base_directory_path, "question_choice_survey_question_survey-imported.csv")
    assert File.exist?(survey_question_choice_imported_file_path)
    

    positive_outcome_sq = new_program.survey_questions.where(question_text: "How was your meeting with your mentoring partner?")[0]
    pop = positive_outcome_sq.question_choices.where(id: positive_outcome_sq.positive_outcome_options.split(",")).collect(&:text)

    popmq = positive_outcome_sq.question_choices.where(id: positive_outcome_sq.positive_outcome_options_management_report.split(",")).collect(&:text)
    assert_equal ["Very Good", "Good"], pop
    assert_equal ["Very Good", "Good"], popmq
  end

  def test_handle_object_creation_with_duplicate_question
    program = programs(:albers)
    profile_question = profile_questions(:profile_questions_9)

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    question_choice_importer = QuestionChoiceImporter.new(program_importer)

    new_question_choice = profile_question.question_choices.new(text: "idiot", position: 4)
    assert_difference "QuestionChoice.count", 1 do
      question_choice_importer.handle_object_creation(new_question_choice, 1, [], "")
    end

    new_question_choice.reload

    assert_no_difference "QuestionChoice.count" do
      question_choice_importer.handle_object_creation(new_question_choice, 1, [], "")
    end

  end
end

