require_relative './../test_helper.rb'

class Ckeditor::AttachmentFilesControllerTest < ActionController::TestCase
  def setup
    super
    @routes = Ckeditor::Engine.routes
  end

  def test_index
    current_user_is :f_admin
    asset = Ckeditor.attachment_file_model.new(program_id: programs(:org_primary).id)
    asset.data = fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png')
    asset.save!

    get :index
    assert_response :success
    assert_select ".fileupload-list .fileupload-file .img-data"
    assert_match /test_pic.png/, response.body
    assert_template partial: 'ckeditor/shared/_asset', count: 1
  end

  def test_create
    current_user_is :f_admin
    assert_difference "Ckeditor::AttachmentFile.count" do
      post :create, params: { qqfile: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png') }
    end
    assert_response :success
    asset = Ckeditor::AttachmentFile.last
    assert_equal "test_pic.png", asset.data_file_name
    assert_equal true, asset.login_required
    assert_equal programs(:org_primary), asset.organization
  end

  def test_create_when_error
    current_user_is :f_admin
    assert_no_difference "Ckeditor::AttachmentFile.count" do
      post :create, params: { qqfile: nil }
    end
  end
end