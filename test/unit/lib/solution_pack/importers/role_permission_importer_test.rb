require_relative './../../../../test_helper.rb'

class RolePermissionImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_role_permission_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    new_program.roles.first.destroy

    new_program.resource_publications.destroy_all

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    role_permission_import_hash = {"mentor" => ["invite_mentors", "become_student"], "student" => ["invite_students", "write_article", "become_mentor"]}

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    role_permission_import_hash.each do |role_name, permission_names|
      permission_names.each do |permission_name|
        assert new_program.has_role_permission?(role_name, permission_name)
      end
    end

    role_permission_file_path = File.join(solution_pack.base_directory_path, "role_permission-imported.csv")
    assert File.exists?(role_permission_file_path)

    delete_base_dir_for_import
  end
end