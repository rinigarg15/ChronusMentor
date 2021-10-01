require_relative './../../../../test_helper.rb'

class ProfileQuestionImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_profile_question_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :survey, :mentoring_model, :admin_view, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    profile_question_texts = []
    profile_question_file_path = File.join(IMPORT_CSV_BASE_PATH, "profile_question.csv")
    csv_content = fixture_file_upload(profile_question_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      profile_question_texts << row["question_text"]
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_question_texts = new_program.organization.profile_questions_with_email_and_name.collect(&:question_text)
    
    profile_question_file_path = File.join(solution_pack.base_directory_path, "profile_question-imported.csv")
    assert File.exists?(profile_question_file_path)

    profile_question_texts.each do |profile_question_text|
      assert imported_question_texts.include?(profile_question_text)
    end

    #test process_profile_answers_count
    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question")
    assert_equal 0, profile_question.profile_answers_count

    #test process_section_id
    section = new_program.organization.sections.where(title: "Unique Section 3").first
    assert_equal section.id, profile_question.section_id
    #test process_organization_id
    assert_equal new_program.organization.id, profile_question.organization_id

    #test process_position
    assert_equal 1, profile_question.position
    assert_equal 2, new_program.organization.profile_questions.find_by(question_text: "Very Unique Gender").position

    #test handle_conditional_profile_questions
    conditional_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Gender")
    assert_equal conditional_question.id, profile_question.conditional_question_id
    assert_nil new_program.organization.profile_questions.find_by(question_text: "Ethnicity").conditional_question_id

    delete_base_dir_for_import
  end

  def test_handle_object_creation_with_location_question
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    location_question = program.organization.profile_questions_with_email_and_name.location_questions.first
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::LOCATION, section_id: program.organization.sections.first.id)
    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    profile_question_importer = ProfileQuestionImporter.new(program_importer)
    assert_no_difference "ProfileQuestion.count" do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end
    assert_equal  location_question, new_profile_question

    location_question.destroy
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::LOCATION, section_id: program.organization.sections.first.id, question_text: "Location")

    assert_difference "ProfileQuestion.count", 1 do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end

    delete_base_dir_for_import
  end

  def test_handle_object_creation_with_same_profile_question_text_and_type
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import

    pq1 = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::TEXT, section_id: program.organization.sections.first.id, question_text: "Test")
    pq2 = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::TEXT, section_id: program.organization.sections.first.id, question_text: "Test")
    pq3 = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::TEXT, section_id: program.organization.sections.first.id, question_text: "Test")

    solution_pack = SolutionPack.new(program: program, created_by: "test admin", description: "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    profile_question_importer = ProfileQuestionImporter.new(program_importer)

    assert_difference "ProfileQuestion.count", 3 do
      new_pq1 = profile_question_importer.handle_object_creation(pq1, 1, [], "")
      new_pq2 = profile_question_importer.handle_object_creation(pq2, 2, [], "")
      new_pq3 = profile_question_importer.handle_object_creation(pq3, 3, [], "")
      assert_equal pq1, new_pq1
      assert_equal pq2, new_pq2
      assert_equal pq3, new_pq3
    end

    delete_base_dir_for_import
  end

  def test_handle_object_creation_with_manager_question
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import
    manager_question = program.organization.profile_questions_with_email_and_name.manager_questions.first
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::MANAGER, section_id: program.organization.sections.first.id, question_text: "Manager")

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    profile_question_importer = ProfileQuestionImporter.new(program_importer)
    assert_no_difference "ProfileQuestion.count" do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end
    assert_equal  manager_question, new_profile_question

    manager_question.destroy
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::MANAGER, section_id: program.organization.sections.first.id, question_text: "Manager")

    assert_difference "ProfileQuestion.count", 1 do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end

    new_profile_question.destroy
    program.enable_feature(FeatureName::MANAGER, false)
    program.organization.enable_feature(FeatureName::MANAGER, false)

    assert_false program.organization.manager_enabled?

    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::MANAGER, section_id: program.organization.sections.first.id, question_text: "Manager")

    assert_difference "ProfileQuestion.count", 1 do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end

    assert program.organization.manager_enabled?

    delete_base_dir_for_import
  end

    def test_handle_object_creation_with_duplicate_question
    program = programs(:albers)
    delete_base_dir_for_import
    copy_base_dir_for_import
    education_question = program.organization.profile_questions_with_email_and_name.where(question_text: "Education", question_type: ProfileQuestion::Type::MULTI_EDUCATION).first
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::EDUCATION, section_id: program.organization.sections.first.id, question_text: "Education")

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    profile_question_importer = ProfileQuestionImporter.new(program_importer)

    #question_type is different
    assert_difference "ProfileQuestion.count", 1 do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end

    new_profile_question.destroy
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::MULTI_EDUCATION, section_id: program.organization.sections.first.id, question_text: "Education")
    assert_no_difference "ProfileQuestion.count" do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end

    assert_equal  education_question, new_profile_question

    education_question.destroy
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::EDUCATION, section_id: program.organization.sections.first.id, question_text: "Education")

    assert_difference "ProfileQuestion.count", 1 do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end
    multi_choice_question = program.organization.profile_questions.where(question_type: ProfileQuestion::Type::MULTI_CHOICE, question_text: "What is your name").first
    new_profile_question = program.organization.profile_questions.new(question_type: ProfileQuestion::Type::MULTI_CHOICE, section_id: program.organization.sections.first.id, question_text: "What is your name")

    assert_no_difference "ProfileQuestion.count" do
      new_profile_question = profile_question_importer.handle_object_creation(new_profile_question, 1, [], "")
    end

    assert_equal new_profile_question.id, multi_choice_question.id
    delete_base_dir_for_import
  end
end