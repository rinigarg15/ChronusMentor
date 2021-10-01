require_relative './../../../../test_helper.rb'

class SurveyImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_survey_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.creation_way = Program::CreationWay::SOLUTION_PACK
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :mentoring_model, :section, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)

    exported_survey_titles = []
    exported_survey_question_texts = []

    survey_file_path = File.join(IMPORT_CSV_BASE_PATH, "survey.csv")
    csv_content = fixture_file_upload(survey_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_survey_titles << row["name"]
    end

    survey_questions_file_path = File.join(IMPORT_CSV_BASE_PATH, "survey_question_survey.csv")
    csv_content = fixture_file_upload(survey_questions_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_survey_question_texts << row["question_text"].strip
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)

    assert_no_difference "CampaignManagement::SurveyCampaign.count" do
      program_importer = ProgramImporter.new(solution_pack).import
    end

    new_program.reload
    imported_survey_titles = []
    imported_survey_question_texts = []
    new_program.surveys.each do |new_survey|
      imported_survey_titles << new_survey.name
      new_survey_questions = new_survey.survey_questions
      assert_equal (1..new_survey_questions.size).to_a, new_survey_questions.pluck(:position)
      imported_survey_question_texts << new_survey_questions.map(&:question_text)
      imported_survey_question_texts << new_survey.matrix_rating_questions.collect(&:question_text)
    end
    imported_survey_question_texts.flatten!

    assert_equal_unordered exported_survey_question_texts, imported_survey_question_texts
    assert_equal_unordered exported_survey_titles, imported_survey_titles

    survey_file_path = File.join(solution_pack.base_directory_path, "survey-imported.csv")
    survey_questions_file_path = File.join(solution_pack.base_directory_path, "survey_question_survey-imported.csv")
    role_file_path = File.join(solution_pack.base_directory_path, "role-imported.csv")

    assert File.exists?(survey_file_path)
    assert File.exists?(survey_questions_file_path)
    assert File.exists?(role_file_path)

    delete_base_dir_for_import
  end
end