require_relative './../../../../test_helper.rb'

class MentoringModelImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_mentoring_model_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    
    include_importers(:settings, :forum, :survey, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    new_program.mentoring_models.destroy_all

    exported_mentoring_model_count = 0
    exported_mentoring_model_titles = []
    mentoring_model_file_path = File.join(IMPORT_CSV_BASE_PATH, "mentoring_model.csv")
    csv_content = fixture_file_upload(mentoring_model_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_mentoring_model_count += 1
      exported_mentoring_model_titles << row["title"]
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_mentoring_model_count = new_program.mentoring_models.count
    imported_mentoring_model_titles = new_program.mentoring_models.collect(&:title)
    assert_equal imported_mentoring_model_count, exported_mentoring_model_count
    assert_equal_unordered imported_mentoring_model_titles, exported_mentoring_model_titles

    role_file_path = File.join(solution_pack.base_directory_path, "role-imported.csv")
    mentoring_model_file_path = File.join(solution_pack.base_directory_path, "mentoring_model-imported.csv")
    object_role_permission_file_path = File.join(solution_pack.base_directory_path, "object_role_permission-imported.csv")
    mentoring_model_link_file_path = File.join(solution_pack.base_directory_path, "mentoring_model_link-imported.csv")
    assert File.exists?(role_file_path)
    assert File.exists?(mentoring_model_file_path)
    assert File.exists?(object_role_permission_file_path)
    assert File.exists?(mentoring_model_link_file_path)

    delete_base_dir_for_import
  end
end