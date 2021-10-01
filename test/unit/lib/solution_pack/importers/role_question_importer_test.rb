require_relative './../../../../test_helper.rb'

class RoleQuestionImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_role_question_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    role_question_texts = []
    role_question_file_path = File.join(IMPORT_CSV_BASE_PATH, "role_question.csv")
    csv_content = fixture_file_upload(role_question_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"

    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question")
    role = new_program.roles.find_by(name: RoleConstants::MENTOR_NAME)
    assert_nil profile_question
    assert_difference "RoleQuestion.count", 6 do
      program_importer = ProgramImporter.new(solution_pack).import
    end
    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question")
    role_question = new_program.role_questions.where(profile_question_id: profile_question.id, role_id: role.id).first

    assert_equal true, role_question.required
    assert_equal RoleQuestion::PRIVACY_SETTING::RESTRICTED, role_question.private
    assert role_question.show_for_roles?(new_program.roles.with_name(RoleConstants::STUDENT_NAME))
    assert role_question.show_for_roles?(new_program.roles.with_name(RoleConstants::MENTOR_NAME))
    assert_false role_question.show_connected_members?
    assert_equal false, role_question.filterable
    assert_equal false, role_question.in_summary
    assert_equal false, role_question.admin_only_editable
    delete_base_dir_for_import
  end

  def test_handle_object_creation
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    role_question_importer = RoleQuestionImporter.new(program_importer)

    last_role_question = program.role_questions.last
    new_role_question = program.role_questions.new(role_id: last_role_question.role_id, profile_question_id: last_role_question.profile_question_id)
    new_role_question.required = !last_role_question.required
    new_role_question.filterable = !last_role_question.filterable
    new_role_question.in_summary = !last_role_question.in_summary
    assert_no_difference "RoleQuestion.count" do
      new_role_question = role_question_importer.handle_object_creation(new_role_question, 1, [], "")
    end
    assert_equal last_role_question.id, new_role_question.reload.id
    assert_equal !last_role_question.required, new_role_question.required
    assert_equal !last_role_question.filterable, new_role_question.filterable
    assert_equal !last_role_question.in_summary, new_role_question.in_summary

    delete_base_dir_for_import
  end

  def test_role_question_import_for_portal
    program = programs(:primary_portal)
    sp = SolutionPack.new
    sp.program = program
    sp.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST
    program_importer = ProgramImporter.new(sp)
    importer = RoleQuestionImporter.new(program_importer)

    CSV.expects(:read).once.returns([[]])
    File.expects(:rename).once
    importer.expects(:import_associated_content).with(importer, ['RoleQuestionPrivacySettingImporter']).once

    importer.import
  end
end