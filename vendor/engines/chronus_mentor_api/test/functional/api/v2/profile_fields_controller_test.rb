require_relative './../../../test_helper.rb'

class Api::V2::ProfileFieldsControllerTest < Api::V2::BasicControllerTest
  # test security
  make_security_tests_for([
    [:get, :index, {}]
  ])

  # index
  def test_index_json_should_success
    update_profile_question_types_appropriately
    https_get :index, params: credentials(format: :json)
    assert_response :success
    assert_equal presenter.list()[:data].to_json, @response.body
  end

  def test_index_xml_should_success
    update_profile_question_types_appropriately
    https_get :index, params: credentials(format: :xml)
    assert_response :success
    assert_equal presenter.list()[:data].to_xml(root: :profile_fields), @response.body
  end

  def test_invalid_formats_to_json_success
    update_profile_question_types_appropriately
    https_get :index, params: credentials(format: "html")
    assert_response :success
    assert_equal presenter.list()[:data].to_json(root: :profile_fields), @response.body
  end

  def test_default_format_to_json_success
    update_profile_question_types_appropriately
    https_get :index, params: credentials(format: nil)
    assert_response :success
    assert_equal presenter.list()[:data].to_json(root: :profile_fields), @response.body
  end

protected
  def presenter
    Api::V2::ProfileFieldsPresenter.new(nil, organization)
  end
end
