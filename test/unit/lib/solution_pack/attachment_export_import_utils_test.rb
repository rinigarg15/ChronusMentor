require_relative './../../../test_helper.rb'
class AttachmentExportImportUtilsTest < ActiveSupport::TestCase

  def test_handle_attachment_export
    forum = forums(:common_forum)
    topic = create_topic(:title => "title", :forum => forum, :user => users(:f_admin))
    post = create_post(:user => users(:f_admin), :topic => topic, :attachment => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))

    SolutionPack::AttachmentExportImportUtils.handle_attachment_export("./tmp/", post, :attachment)
    assert File.exists?("./tmp/#{post.id}")
    assert File.exists?("./tmp/#{post.id}/test_pic.png")
    FileUtils.rm "./tmp/#{post.id}/test_pic.png"
    FileUtils.rm_rf "./tmp/#{post.id}"
  end

  def test_handle_attachment_import
    forum = forums(:common_forum)
    topic = create_topic(:title => "title", :forum => forum, :user => users(:f_admin))
    post = create_post(:user => users(:f_admin), :topic => topic, :attachment => fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png'))

    SolutionPack::AttachmentExportImportUtils.handle_attachment_export("./tmp/", post, :attachment)

    new_post = create_post(:user => users(:f_admin), :topic => topic)
    SolutionPack::AttachmentExportImportUtils.handle_attachment_import("./tmp/", new_post, :attachment, 'test_pic.png', post.id)
    assert new_post.attachment.exists?
    FileUtils.rm "./tmp/#{post.id}/test_pic.png"
    FileUtils.rm_rf "./tmp/#{post.id}"
  end

end