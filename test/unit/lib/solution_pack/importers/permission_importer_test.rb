require_relative './../../../../test_helper.rb'

class PermissionImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_permission_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    Permission.find_by(name: "write_article").destroy

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    exported_permissions = ["invite_mentors", "invite_students", "write_article"]

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    exported_permissions.each do |permission_name|
      assert Permission.find_by(name: permission_name).present?
    end

    permission_file_path = File.join(solution_pack.base_directory_path, "permission-imported.csv")
    assert File.exists?(permission_file_path)

    delete_base_dir_for_import
  end
end