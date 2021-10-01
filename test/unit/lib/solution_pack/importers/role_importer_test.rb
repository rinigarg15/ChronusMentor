require_relative './../../../../test_helper.rb'

class RoleImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_role_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.creation_way = Program::CreationWay::SOLUTION_PACK
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!
    new_program.set_owner!

    include_importers(:settings, :forum, :survey, :mentoring_model, :section, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)

    exported_forum_names = []
    exported_topic_titles = []

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)

    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload
    admin_role = new_program.roles.find_by(name: RoleConstants::ADMIN_NAME)
    mentor_role = new_program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    mentee_role = new_program.roles.find_by(name: RoleConstants::STUDENT_NAME)

    assert_equal false, admin_role.eligibility_rules
    assert_equal false, mentor_role.eligibility_rules
    assert_equal true, mentee_role.eligibility_rules
    assert mentee_role.slot_config_required?
    assert mentor_role.slot_config_optional?
    assert_false admin_role.slot_config_enabled?
    assert_equal 7, admin_role.max_connections_limit
    assert_equal 8, mentor_role.max_connections_limit
    assert_equal 9, mentee_role.max_connections_limit

    role_file_path = File.join(solution_pack.base_directory_path, "role-imported.csv")

    assert File.exists?(role_file_path)
    delete_base_dir_for_import
  end
end