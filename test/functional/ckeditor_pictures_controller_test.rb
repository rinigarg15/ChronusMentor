require_relative './../test_helper.rb'

class Ckeditor::PicturesControllerTest < ActionController::TestCase
  def setup
    super
    @routes = Ckeditor::Engine.routes
  end

  def test_create
    current_user_is :f_admin
    assert_difference "Ckeditor::Picture.count" do
      post :create, params: { qqfile: fixture_file_upload(File.join('files', 'test_pic.png'), 'image/png') }
    end
    assert_response :success
    asset = Ckeditor::Picture.last
    assert_equal "test_pic.png", asset.data_file_name
    assert_false asset.login_required
    assert_equal programs(:org_primary), asset.organization
  end
end