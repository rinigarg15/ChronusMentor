require_relative './../../../../test_helper.rb'

class AdminViewColumnImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_admin_view_column_import
    org = programs(:org_primary)
    delete_base_dir_for_import
    copy_base_dir_for_import

    new_program = org.programs.new
    new_program.name = "Test Program"
    new_program.root = "test-program"
    new_program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING
    new_program.save!

    include_importers(:settings, :forum, :mentoring_model, :abstract_campaign, :resource, :mailer_template, :group_closure_reason, :overview_pages)

    new_program.admin_views.destroy_all

    exported_admin_view_column_count = 0
    admin_view_column_file_path = File.join(IMPORT_CSV_BASE_PATH, "admin_view_column.csv")
    csv_content = fixture_file_upload(admin_view_column_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_admin_view_column_count += 1
    end

    solution_pack = SolutionPack.new(:program => new_program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    MatchConfig.any_instance.stubs(:can_create_match_config_discrepancy_cache?).returns(false)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload

    imported_admin_view_column_count = new_program.admin_views.map{|av| av.admin_view_columns}.flatten.count
    assert_equal imported_admin_view_column_count, exported_admin_view_column_count

    admin_view_file_path = File.join(solution_pack.base_directory_path, "admin_view-imported.csv")
    admin_view_column_file_path = File.join(solution_pack.base_directory_path, "admin_view_column-imported.csv")
    assert File.exists?(admin_view_file_path)
    assert File.exists?(admin_view_column_file_path)

    new_admin_view_columns = new_program.admin_views.collect(&:admin_view_columns)
    profile_question = new_program.organization.profile_questions.find_by(question_text: "Very Unique Profile Question")
    new_admin_view_column = nil
    admin_view = new_program.admin_views.where(title: "Unique Users With Low Profile Scores").first
    new_admin_view_columns.flatten.uniq.each do |navc|
      new_admin_view_column = navc if navc.profile_question.present? && navc.profile_question.question_text == "Very Unique Profile Question"
    end
    assert_equal profile_question.id, new_admin_view_column.profile_question_id
    assert_equal admin_view.id, new_admin_view_column.admin_view_id
    delete_base_dir_for_import
  end

  def test_handle_object_creation
    program = programs(:albers)
    time_now = Time.now
    mock_now(time_now)

    delete_base_dir_for_import
    copy_base_dir_for_import

    all_users = program.admin_views.where(title: "All Users").first

    first_name_column = all_users.admin_view_columns.find_by(column_key: AdminViewColumn::Columns::Key::FIRST_NAME)

    new_admin_view_column = all_users.admin_view_columns.new(column_key: AdminViewColumn::Columns::Key::FIRST_NAME, position: 5)

    solution_pack = SolutionPack.new(:program => program, :created_by => "test admin", :description => "test solution pack")
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    program_importer = ProgramImporter.new(solution_pack)
    admin_view_column_importer = AdminViewColumnImporter.new(program_importer)
    assert_no_difference "AdminViewColumn.count" do
      new_admin_view_column = admin_view_column_importer.handle_object_creation(new_admin_view_column, 1, [], "")
    end

    assert_equal first_name_column, new_admin_view_column

    admin_view_column = AdminViewColumn.create!(:admin_view => all_users, :profile_question_id => 1, :position => 9)
    new_admin_view_column = all_users.admin_view_columns.new(profile_question_id: 1, position: 5)

    assert_no_difference "AdminViewColumn.count" do
      new_admin_view_column = admin_view_column_importer.handle_object_creation(new_admin_view_column, 1, [], "")
    end
    assert_equal admin_view_column, new_admin_view_column

    delete_base_dir_for_import
  end
end