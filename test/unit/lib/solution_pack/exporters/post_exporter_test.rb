require_relative './../../../../test_helper.rb'

class PostExporterTest < ActiveSupport::TestCase

  def test_post_export
    program = programs(:albers)
    FileUtils.rm_rf(Rails.root.to_s + SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s + SP_BASE_PATH_FOR_EXPORT_TEST)
    SolutionPack.any_instance.expects(:rand).with(10000).returns(5678)
    Time.any_instance.expects(:to_i).times(3).returns(1234)

    forum = forums(:forums_2)
    topic = create_topic(forum: forum)
    post = create_post(topic: topic)
    program.reload

    solution_pack = SolutionPack.new(program: program, created_by: "need")
    solution_pack.initialize_solution_pack_for_export
    program_exporter = ProgramExporter.new(program, solution_pack)
    forum_exporter = ForumExporter.new(program, program_exporter)
    topic_exporter = TopicExporter.new(program, forum_exporter)
    post_exporter = PostExporter.new(program, topic_exporter)
    post_exporter.export

    assert_equal post_exporter.objs, [post]
    assert_equal post_exporter.file_name, 'post'
    assert_equal post_exporter.program, program
    assert_equal post_exporter.parent_exporter, topic_exporter

    exported_post_ids = []
    assert File.exist?(solution_pack.base_path + 'post.csv')
    CSV.foreach(solution_pack.base_path + 'post.csv', headers: true) do |row|
      exported_post_ids << row["id"].to_i
    end
    assert_equal_unordered exported_post_ids, [post.id]

    FileUtils.rm_rf(Rails.root.to_s + SP_BASE_PATH_FOR_EXPORT_TEST) if File.exist?(Rails.root.to_s + SP_BASE_PATH_FOR_EXPORT_TEST)
  end
end