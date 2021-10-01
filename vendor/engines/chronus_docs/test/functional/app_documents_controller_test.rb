require_relative './../test_helper.rb'

class AppDocumentsControllerTest < ActionController::TestCase

  def test_index_permission_denied
    get :index
    assert_redirected_to super_login_path
  end

  def test_index_success_no_data
    login_as_super_user
    get :index
    assert_response :success
    assert_equal [], assigns(:documents)
  end

  def test_index_success
    login_as_super_user
    doc = create_app_document
    get :index
    assert_response :success
    assert_equal [doc], assigns(:documents)
  end

  def test_show_permission_denied
    doc = create_app_document

    get :show, params: { id: doc.id }
    assert_redirected_to super_login_path
  end

  def test_show_success
    doc = create_app_document

    login_as_super_user
    get :show, params: { id: doc.id }
    assert_equal doc, assigns(:document)
  end
end