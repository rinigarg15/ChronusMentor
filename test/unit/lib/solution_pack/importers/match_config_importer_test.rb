require_relative './../../../../test_helper.rb'

class MatchConfigImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_match_config_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.creation_way = Program::CreationWay::SOLUTION_PACK
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    new_program.match_configs.destroy_all

    include_importers(:settings, :forum, :survey, :mentoring_model, :abstract_campaign, :admin_view, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    exported_match_config_count = 0
    match_config_file_path = File.join(IMPORT_CSV_BASE_PATH, "match_config.csv")
    csv_content = fixture_file_upload(match_config_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_match_config_count += 1
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)
    program_importer = ProgramImporter.new(solution_pack).import
    new_program.reload

    imported_match_config_count = new_program.match_configs.count
    assert_equal imported_match_config_count, exported_match_config_count

    section_file_path = File.join(solution_pack.base_directory_path, "section-imported.csv")
    profile_question_file_path = File.join(solution_pack.base_directory_path, "profile_question-imported.csv")
    role_question_file_path = File.join(solution_pack.base_directory_path, "role_question-imported.csv")
    match_config_file_path = File.join(solution_pack.base_directory_path, "match_config-imported.csv")
    assert File.exists?(section_file_path)
    assert File.exists?(profile_question_file_path)
    assert File.exists?(role_question_file_path)
    assert File.exists?(match_config_file_path)

   delete_base_dir_for_import
  end

  def test_match_config_uniqueness_validation
    #validates_uniqueness_of :student_question_id, :scope => [:mentor_question_id, :program_id]
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    pq = create_profile_question(organization: program.organization)
    mentor_question = role_questions(:string_role_q)
    student_question = create_role_question(profile_question: pq, role_names: [RoleConstants::STUDENT_NAME])
    match_config1 = MatchConfig.new(program: program, student_question: student_question, mentor_question: mentor_question)
    match_config2 = MatchConfig.new(program: program, student_question: student_question, mentor_question: mentor_question)

    solution_pack = SolutionPack.new(program: program, created_by: "test admin", description: "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    match_config_importer = MatchConfigImporter.new(program_importer)

    assert_difference "MatchConfig.count" do
      new_match_config = match_config_importer.handle_object_creation(match_config1, 1, [], "")
      assert_equal match_config1, new_match_config
    end

    assert_no_difference "MatchConfig.count" do
      new_match_config = match_config_importer.handle_object_creation(match_config2, 2, [], "")
    end

    delete_base_dir_for_import
  end
end