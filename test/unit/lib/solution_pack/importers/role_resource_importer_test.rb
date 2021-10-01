require_relative './../../../../test_helper.rb'

class RoleResourceImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_role_resource_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    role_resources = new_program.roles.collect(&:role_resources).flatten
    RoleResource.where(id: role_resources.map(&:id)).destroy_all
    new_program.reload

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)

    exported_role_id_resource_count_hash = {}
    role_resource_file_path = File.join(IMPORT_CSV_BASE_PATH, "role_resource.csv")
    csv_content = fixture_file_upload(role_resource_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_role_id_resource_count_hash[row["role_id"]] ||= 0
      exported_role_id_resource_count_hash[row["role_id"]] += 1
    end

    exported_role_name_resource_count_hash = {}
    role_file_path = File.join(IMPORT_CSV_BASE_PATH, "role.csv")
    csv_content = fixture_file_upload(role_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_role_name_resource_count_hash[row["name"]] = exported_role_id_resource_count_hash[row["id"]] || 0
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_role_resource_count = new_program.roles.collect(&:role_resources).flatten.count
    imported_role_name_resource_count_hash = {}
    new_program.roles.each do |role|
      imported_role_name_resource_count_hash[role.name] = role.role_resources.count
    end
    assert_equal imported_role_name_resource_count_hash, exported_role_name_resource_count_hash

    role_resource_file_path = File.join(solution_pack.base_directory_path, "role_resource-imported.csv")
    assert File.exists?(role_resource_file_path)

    delete_base_dir_for_import
  end
end