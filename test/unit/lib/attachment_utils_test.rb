require_relative './../../test_helper.rb'

class AttachmentUtilsTest < ActiveSupport::TestCase
  def test_copy_attachment
    group = groups(:group_5)
    task_1 = create_mentoring_model_task(from_template: false, group: group, user: group.students.first)
    comment = create_task_comment(task_1, content: "Test Comment comment", attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    scrap = Scrap.new
    AttachmentUtils.copy_attachment(comment, scrap)
    assert_equal comment.attachment_file_name, scrap.attachment_file_name
    assert_equal comment.attachment_content_type, scrap.attachment_content_type
    assert_equal comment.attachment_file_size, scrap.attachment_file_size
  end

  def test_get_remote_data
    group = groups(:group_5)
    task_1 = create_mentoring_model_task(from_template: false, group: group, user: group.students.first)
    comment = create_task_comment(task_1, content: "Test Comment comment", attachment: fixture_file_upload(File.join("files", "some_file.txt"), "text/text"))
    scrap = Scrap.new
    io = fixture_file_upload(File.join("files", "some_file.txt"), "text/text")
    io.stubs(:base_uri).returns(stub(:path => "/some_file.txt"))
    AttachmentUtils.expects(:open).with(URI.parse("http://dummy.com/some_file.txt")).returns(io)
    scrap.attachment = AttachmentUtils.get_remote_data("http://dummy.com/some_file.txt")
    assert_equal "text/text", scrap.attachment_content_type 
    assert_equal "some_file.txt", scrap.attachment_file_name
  end
end