require_relative './../../../../test_helper.rb'

class CustomizedTermImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_customized_term_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :mentoring_model, :section, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)
    
    new_program.roles.where(name: RoleConstants::MENTOR_NAME).first.destroy
    new_program.reload

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import

    
    new_program.reload
    mentor_role_term = new_program.roles.where(name: RoleConstants::MENTOR_NAME).first.customized_term
    assert_equal mentor_role_term.term, "New Mentor"
    assert_equal mentor_role_term.term_downcase, "New mentor"
    assert_equal mentor_role_term.pluralized_term, "New Mentors"
    assert_equal mentor_role_term.pluralized_term_downcase, "New mentors"
    assert_equal mentor_role_term.articleized_term, "New a Mentor"
    assert_equal mentor_role_term.articleized_term_downcase, "New a mentor"

    mentee_role_term = new_program.roles.where(name: RoleConstants::STUDENT_NAME).first.customized_term
    assert_equal mentee_role_term.term, "New Mentee"

    role_name_file_path = File.join(solution_pack.base_directory_path, "customized_term_role-imported.csv")
    program_name_file_path = File.join(solution_pack.base_directory_path, "customized_term_program-imported.csv")
    
    connection_term = new_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM)
    resource_term = new_program.term_for(CustomizedTerm::TermType::RESOURCE_TERM)
    article_term = new_program.term_for(CustomizedTerm::TermType::ARTICLE_TERM)
    meeting_term = new_program.term_for(CustomizedTerm::TermType::MEETING_TERM)
    mentoring_term = new_program.term_for(CustomizedTerm::TermType::MENTORING_TERM)

    assert_equal "Connection", connection_term.term
    assert_equal "Archive", resource_term.term
    assert_equal "Helpdesk", article_term.term
    assert_equal "Session", meeting_term.term
    assert_equal "Connecting", mentoring_term.term

    assert_equal "a session", meeting_term.articleized_term_downcase
    assert_equal "session", meeting_term.term_downcase
    assert_equal "Sessions", meeting_term.pluralized_term
    assert_equal "sessions", meeting_term.pluralized_term_downcase
    assert_equal "a Session", meeting_term.articleized_term


    assert File.exists?(role_name_file_path)
    assert File.exists?(program_name_file_path)

    delete_base_dir_for_import
  end
end