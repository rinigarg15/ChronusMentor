require_relative './../../../../test_helper.rb'

class ConnectionQuestionImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_connection_questions_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :mentoring_model, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    exported_connection_question_count = 0
    exported_connection_question_texts = []
    exported_connection_question_titles = []
    connection_question_file_path = File.join(IMPORT_CSV_BASE_PATH, "connection_question.csv")
    csv_content = fixture_file_upload(connection_question_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_connection_question_count += 1
      exported_connection_question_texts << row["question_text"].strip
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_connection_question_texts = new_program.connection_questions.collect(&:question_text)

    imported_connection_questions_count = new_program.connection_questions.count
    assert_equal imported_connection_questions_count, exported_connection_question_count

    assert_equal_unordered exported_connection_question_texts, imported_connection_question_texts

    connection_question_file_path = File.join(solution_pack.base_directory_path, "connection_question-imported.csv")
    assert File.exists?(connection_question_file_path)
  end
end