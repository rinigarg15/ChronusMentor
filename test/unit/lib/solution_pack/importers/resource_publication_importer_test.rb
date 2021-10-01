require_relative './../../../../test_helper.rb'

class ResourcePublicationImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_resource_publication_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    new_program.resource_publications.destroy_all

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)

    exported_resource_publication_count = 0
    resource_publication_file_path = File.join(IMPORT_CSV_BASE_PATH, "resource_publication.csv")
    csv_content = fixture_file_upload(resource_publication_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_resource_publication_count += 1
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_resource_publication_count = new_program.resource_publications.count
    assert_equal imported_resource_publication_count, exported_resource_publication_count

    resource_publication_file_path = File.join(solution_pack.base_directory_path, "resource_publication-imported.csv")
    role_resource_file_path = File.join(solution_pack.base_directory_path, "role_resource-imported.csv")
    assert File.exists?(resource_publication_file_path)
    assert File.exists?(role_resource_file_path)

    delete_base_dir_for_import
  end
end