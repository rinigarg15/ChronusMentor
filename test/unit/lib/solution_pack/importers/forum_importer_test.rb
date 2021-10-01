require_relative './../../../../test_helper.rb'

class ForumImporterTest < ActiveSupport::TestCase

  IMPORT_CSV_BASE_PATH = "files/solution_pack_import"

  def test_forum_import
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

    include_importers(:settings, :survey, :mentoring_model, :section, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)
    exported_forum_names = []
    exported_topic_titles = []

    forum_file_path = File.join(IMPORT_CSV_BASE_PATH, "forum.csv")
    csv_content = fixture_file_upload(forum_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_forum_names << row["name"]
    end

    topic_file_path = File.join(IMPORT_CSV_BASE_PATH, "topic.csv")
    csv_content = fixture_file_upload(topic_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_topic_titles << row["title"]
    end

    solution_pack = SolutionPack.new(program: new_program, created_by: "test admin", description: "test solution pack", is_sales_demo: true)
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)

    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload
    imported_forum_names = new_program.forums.collect(&:name)
    imported_topic_titles = new_program.forums.map{|f| f.topics}.flatten.collect(&:title)
    assert_equal_unordered exported_topic_titles, imported_topic_titles
    assert_equal_unordered exported_forum_names, imported_forum_names

    forum_file_path = File.join(solution_pack.base_directory_path, "forum-imported.csv")
    topic_file_path = File.join(solution_pack.base_directory_path, "topic-imported.csv")
    role_file_path = File.join(solution_pack.base_directory_path, "role-imported.csv")
    post_file_path = File.join(solution_pack.base_directory_path, "post-imported.csv")

    assert File.exists?(forum_file_path)
    assert File.exists?(topic_file_path)
    assert File.exists?(role_file_path)
    assert File.exists?(post_file_path)

    delete_base_dir_for_import
  end

  def test_forum_import_sales_demo
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
    include_importers(:settings, :survey, :mentoring_model, :section, :admin_view, :abstract_campaign, :mailer_template, :group_closure_reason, :overview_pages)

    exported_forum_names = []
    exported_topic_titles = []

    forum_file_path = File.join(IMPORT_CSV_BASE_PATH, "forum.csv")
    csv_content = fixture_file_upload(forum_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    csv.each do |row|
      exported_forum_names << row["name"]
    end

    topic_file_path = File.join(IMPORT_CSV_BASE_PATH, "topic.csv")
    csv_content = fixture_file_upload(topic_file_path, "text/csv")
    csv = CSV.parse(csv_content, :headers => true)
    exported_user_ids = {}
    csv.each do |row|
      exported_topic_titles << row["title"]
      exported_user_ids[row["user_id"].to_i] = row["user_id"].to_i
    end
    User.where(id: exported_user_ids.values).update_all(:program_id => new_program.id)
    modified_user_ids = exported_user_ids.to_a
    modified_user_ids.last[1] = nil
    exported_user_ids = Hash[modified_user_ids]
    solution_pack = SolutionPack.new(program: new_program, created_by: "test admin", description: "test solution pack", sales_demo_mapper: {organization: {}, resource: {}, user: exported_user_ids}, is_sales_demo: true)
    solution_pack.base_directory_path = SP_BASE_PATH_FOR_IMPORT_TEST+"/"
    set_ck_editor_attributes_for_solution_pack(solution_pack)

    Forum.any_instance.expects(:can_be_accessed_by?).at_least_once.returns(:true)
    program_importer = ProgramImporter.new(solution_pack).import

    new_program.reload
    modified_user_ids.last[1] = solution_pack.program.owner.id
    exported_user_ids = Hash[modified_user_ids]
    imported_forum_names = new_program.forums.collect(&:name)
    imported_topics = new_program.forums.map{|f| f.topics}.flatten
    imported_topic_titles = imported_topics.collect(&:title)
    imported_topic_user_ids = imported_topics.collect(&:user_id)

    assert_equal_unordered exported_user_ids.values, imported_topic_user_ids
    assert_equal_unordered exported_topic_titles, imported_topic_titles
    assert_equal_unordered exported_forum_names, imported_forum_names

    forum_file_path = File.join(solution_pack.base_directory_path, "forum-imported.csv")
    topic_file_path = File.join(solution_pack.base_directory_path, "topic-imported.csv")
    role_file_path = File.join(solution_pack.base_directory_path, "role-imported.csv")
    post_file_path = File.join(solution_pack.base_directory_path, "post-imported.csv")

    assert File.exists?(forum_file_path)
    assert File.exists?(topic_file_path)
    assert File.exists?(role_file_path)
    assert File.exists?(post_file_path)

    delete_base_dir_for_import
  end
end
