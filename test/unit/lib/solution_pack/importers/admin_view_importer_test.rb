require_relative './../../../../test_helper.rb'

class AdminViewImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_admin_view_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    time_now = Time.now

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :mentoring_model, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)
    mock_now(time_now)

    new_program.admin_views.destroy_all

    exported_admin_view_titles = []
    admin_view_file_path = File.join(IMPORT_CSV_BASE_PATH, "admin_view.csv")
    csv_content = fixture_file_upload(admin_view_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_admin_view_titles << row["title"]
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_admin_view_titles = new_program.admin_views.pluck(:title)
    assert_equal_unordered exported_admin_view_titles, imported_admin_view_titles

    admin_view_file_path = File.join(solution_pack.base_directory_path, "admin_view-imported.csv")
    admin_view_column_file_path = File.join(solution_pack.base_directory_path, "admin_view_column-imported.csv")
    assert File.exists?(admin_view_file_path)
    assert File.exists?(admin_view_column_file_path)

    admin_views = AdminView.where(title: "Unique Users With Low Profile Scores")

    assert_equal 1, admin_views.count
    assert_equal new_program.id, admin_views.first.program.id

    filter_params = admin_views.first.filter_params_hash
    question_id = filter_params["profile"]["questions"].first[1]["question"].to_i
    question_id_2 = filter_params["profile"]["questions"]["questions_2"]["question"].to_i
    pq_choice_id = filter_params["profile"]["questions"]["questions_2"]["choice"].to_i
    profile_question_id = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question").id
    profile_question2 = new_program.organization.profile_questions.find_by(question_text: "Very Unique Gender")
    pq_expected_choice_id = profile_question2.question_choices.find_by(text: "Male").id
    assert_equal question_id, profile_question_id
    assert_equal question_id_2, profile_question2.id
    assert_equal pq_choice_id, pq_expected_choice_id

    assert_not_empty filter_params["survey"]
    assert_not_empty filter_params["survey"]["survey_questions"]
    assert_not_empty filter_params["survey"]["user"]

    survey_id = filter_params["survey"]["survey_questions"].first[1]["survey_id"].to_i
    survey_id_for_survey_user_filter = filter_params["survey"]["user"]["survey_id"].to_i
    question_id = filter_params["survey"]["survey_questions"].first[1]["question"].split("answers").last.to_i
    choice_id = filter_params["survey"]["survey_questions"].first[1]["choice"].to_i
    survey_question = new_program.surveys.find_by(name: "Mentoring Connection Activity Feedback").survey_questions.find_by(question_text: "How effective is this mentoring connection?")
    survey_question_id = survey_question.id
    expected_qc_id = survey_question.question_choices.find_by(text: "Good").id
    assert_equal question_id, survey_question_id
    assert_equal expected_qc_id, choice_id
    assert_equal survey_id, new_program.surveys.find_by(name: "Mentoring Connection Activity Feedback").id
    assert_equal survey_id_for_survey_user_filter, new_program.surveys.find_by(name: "Mentoring Connection Activity Feedback").id

    #test process_favourited_at
    admin_view = new_program.admin_views.where(title: "All Administrators").first
    assert_equal time_now.to_i, admin_view.favourited_at.to_i
    assert_nil admin_views.first.favourited_at

    delete_base_dir_for_import
  end

  def test_handle_object_creation
    program = programs(:albers)
    time_now = Time.now
    mock_now(time_now)

    delete_base_dir_for_import
    copy_base_dir_for_import

    all_users = program.admin_views.where(title: "All Users")

    new_admin_view = program.admin_views.new(title: "All Users", description: "New description", filter_params: "---
:roles_and_status:
  role_filter_1:
    type: include
    roles:
    - admin
    - mentor
    - student
")

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    admin_view_importer = AdminViewImporter.new(program_importer)
    assert_no_difference "AdminView.count" do
      new_admin_view = admin_view_importer.handle_object_creation(new_admin_view, 1, [], "")
    end

    assert_equal all_users.first, new_admin_view
    assert_equal "New description", new_admin_view.description

    new_admin_view = program.admin_views.new(title: "New Random title", favourited_at: time_now, default_view: all_users.first.default_view, description: "New description2", filter_params: "---
:roles_and_status:
  role_filter_1:
    type: include
    roles:
    - admin
    - mentor
    - student
")
    assert_no_difference "AdminView.count" do
      new_admin_view = admin_view_importer.handle_object_creation(new_admin_view, 1, [], "")
    end

    assert_equal all_users.first, new_admin_view
    assert_equal "New description2", new_admin_view.description
    assert_equal "All Users", new_admin_view.title
    assert_not_equal time_now.to_i, new_admin_view.favourited_at.to_i

    all_users.first.update_attributes(favourite: false, favourited_at: nil)

    new_admin_view = program.admin_views.new(title: "New Random title", favourite: true, favourited_at: time_now, default_view: all_users.first.default_view, description: "New description2", filter_params: "---
:roles_and_status:
  role_filter_1:
    type: include
    roles:
    - admin
    - mentor
    - student
")
    assert_no_difference "AdminView.count" do
      new_admin_view = admin_view_importer.handle_object_creation(new_admin_view, 1, [], "")
    end

    assert_equal all_users.first, new_admin_view
    assert_equal "New description2", new_admin_view.description
    assert_equal "All Users", new_admin_view.title
    assert_equal time_now.to_i, new_admin_view.favourited_at.to_i
    delete_base_dir_for_import
  end
end