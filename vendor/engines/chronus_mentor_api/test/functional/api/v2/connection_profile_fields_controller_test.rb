require_relative './../../../test_helper.rb'

class Api::V2::ConnectionProfileFieldsControllerTest < Api::V2::BasicControllerTest
  # test security
  make_security_tests_for([
    [:get, :index, {}]
  ])

  # index
  def test_index_json_should_success
    Api::V2::ConnectionProfileFieldsController.any_instance.expects(:audit_activity).never
    https_get :index, params: credentials(format: :json)
    assert_response :success
    assert_equal presenter.list[:data].to_json, @response.body
  end

  def test_index_xml_should_success
    https_get :index, params: credentials(format: :xml)
    assert_response :success
    assert_equal presenter.list[:data].to_xml(root: :connection_profiles), @response.body
  end

protected
  def presenter
    Api::V2::ConnectionProfileFieldsPresenter.new(program)
  end
end
