require_relative './../../../../test_helper'

class ForumExporterTest < ActiveSupport::TestCase

  def test_forum_export
    program = programs(:albers)
    # Group forums are not exported
    group_forum_setup
    create_topic(forum: @forum, user: @group.mentors.first)

    solution_pack = SolutionPack.new(program: program, created_by: "need", is_sales_demo: true)
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    forum_exporter = ForumExporter.new(program, program_exporter)
    forum_exporter.export

    forums = program.forums
    program_forums = forums.program_forums
    assert_equal (forums.size - 1), program_forums.size
    topics = program_forums.map(&:topics).flatten
    role_references = RoleReference.joins(:role).where(roles: { program_id: program.id } ).select { |rr| rr.ref_obj_type == Forum.name }

    exported_forum_ids = []
    exported_topic_ids = []
    exported_role_refs = []

    assert_equal forum_exporter.parent_exporter, program_exporter
    assert_equal forum_exporter.program, program
    assert_equal forum_exporter.file_name, "forum"

    forum_file_path = solution_pack.base_path + 'forum.csv'
    assert File.exist?(forum_file_path)
    CSV.foreach(forum_file_path, headers: true) do |row|
      exported_forum_ids << row["id"].to_i
    end

    topic_file_path = solution_pack.base_path + 'topic.csv'
    assert File.exist?(topic_file_path)
    CSV.foreach(topic_file_path, headers: true) do |row|
      exported_topic_ids << row["id"].to_i
    end

    role_references_file_path = solution_pack.base_path + 'role_reference_forum.csv'
    assert File.exist?(role_references_file_path)
    CSV.foreach(role_references_file_path, headers: true) do |row|
      exported_role_refs << row["id"].to_i
    end

    assert_equal_unordered exported_forum_ids, program_forums.collect(&:id)
    assert_equal_unordered exported_topic_ids, topics.collect(&:id)
    assert_equal_unordered exported_role_refs, role_references.collect(&:id)

    File.delete(topic_file_path)
    File.delete(forum_file_path)
    File.delete(role_references_file_path)
  end

  def test_forum_model_unchanged
    expected_attribute_names = ["id", "program_id", "description", "topics_count", "name", "group_id", "created_at", "updated_at"]
    assert_equal_unordered expected_attribute_names, Forum.attribute_names

    forum_column_hash = Forum.columns_hash
    assert_equal forum_column_hash["program_id"].type, :integer
    assert_equal forum_column_hash["description"].type, :text
    assert_equal forum_column_hash["topics_count"].type, :integer
    assert_equal forum_column_hash["name"].type, :string
    assert_equal forum_column_hash["group_id"].type, :integer
  end
end