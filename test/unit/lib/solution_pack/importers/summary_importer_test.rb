require_relative './../../../../test_helper.rb'

class SummaryImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_summarys_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :mentoring_model, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    exported_summary_count = 0
    summary_file_path = File.join(IMPORT_CSV_BASE_PATH, "summary_connection_question.csv")
    csv_content = fixture_file_upload(summary_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_summary_count += 1
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_summaries_count = new_program.summaries.count
    assert_equal imported_summaries_count, exported_summary_count

    summary_file_path = File.join(solution_pack.base_directory_path, "summary_connection_question-imported.csv")
    assert File.exists? (summary_file_path)
  end
end