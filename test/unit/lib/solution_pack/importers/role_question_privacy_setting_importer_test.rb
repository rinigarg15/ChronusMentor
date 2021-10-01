require_relative './../../../../test_helper.rb'

class RoleQuestionPrivacySettingImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_role_question_privacy_setting_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)
    
    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"

    assert_difference "RoleQuestionPrivacySetting.count", 2 do
      program_importer = ProgramImporter.new(solution_pack).import
    end

    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question")
    role_question = new_program.role_questions.where(profile_question_id: profile_question).first
    assert role_question.restricted?
    assert role_question.show_for_roles?(new_program.roles.with_name(RoleConstants::MENTOR_NAME))

    profile_question = new_program.organization.profile_questions.find_by(question_text: "Phone")
    role_question = new_program.role_questions.where(profile_question_id: profile_question, role_id: new_program.get_role(RoleConstants::MENTOR_NAME)).first
    assert role_question.restricted?
    assert role_question.show_for_roles?(new_program.roles.with_name(RoleConstants::STUDENT_NAME))

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
    role_question_privacy_setting_importer = RoleQuestionPrivacySettingImporter.new(role_question_importer)

    last_privacy_setting = program.role_questions.collect(&:privacy_settings).flatten.last
    last_role_question = last_privacy_setting.role_question
    new_privacy_setting = last_role_question.privacy_settings.new(role_id: last_privacy_setting.role_id, setting_type: last_privacy_setting.setting_type)
    assert_no_difference "RoleQuestionPrivacySetting.count" do
      new_privacy_setting = role_question_privacy_setting_importer.handle_object_creation(new_privacy_setting, 1, [], "")
    end
    assert_equal  last_privacy_setting, new_privacy_setting

    delete_base_dir_for_import
  end

end