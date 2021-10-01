require_relative './../../../../test_helper'

class TopicExporterTest < ActiveSupport::TestCase

  def test_topic_export
    program = programs(:albers)
    solution_pack = SolutionPack.new(:program => program, :created_by => "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    fe = ForumExporter.new(program, program_exporter)
    te = TopicExporter.new(program, fe)
    te.export

    forums = program.forums
    topics = forums.map{|forum| forum.topics}.flatten

    exported_topic_ids = []

    assert_equal te.parent_exporter, fe
    assert_equal te.program, program
    assert_equal te.file_name, "topic"

    topicFilePath = solution_pack.base_path+'topic.csv'
    assert File.exist?(topicFilePath)
    CSV.foreach(topicFilePath, headers: true) do |row|
      exported_topic_ids << row["id"].to_i
    end

    File.delete(topicFilePath)
  end

  def test_topic_model_unchanged
    expected_attribute_names = ["id", "forum_id", "user_id", "title", "created_at", "updated_at", "hits", "posts_count", "sticky_position", "body"]
    assert_equal_unordered expected_attribute_names, Topic.attribute_names

    topic_column_hash = Topic.columns_hash
    assert_equal topic_column_hash["forum_id"].type, :integer
    assert_equal topic_column_hash["user_id"].type, :integer
    assert_equal topic_column_hash["title"].type, :string
    assert_equal topic_column_hash["created_at"].type, :datetime
    assert_equal topic_column_hash["updated_at"].type, :datetime
    assert_equal topic_column_hash["hits"].type, :integer
    assert_equal topic_column_hash["posts_count"].type, :integer
    assert_equal topic_column_hash["sticky_position"].type, :integer
  end
end