require_relative './../../../test_helper.rb'

class Api::V2::MentoringTemplatesControllerTest < Api::V2::BasicControllerTest
  # test security
  make_security_tests_for([
    [:get, :index, {}]
  ])

  # index
  def test_index_json_should_fail
    https_get :index, params: credentials(format: :json)
    assert_response 404
    assert_equal "Access Unauthorised", @response.body
  end

  def test_index_xml_should_fail
    https_get :index, params: credentials(format: :xml)
    assert_response 404
    assert_equal "Access Unauthorised", @response.body
  end

  def test_index_json_should_success
    program.organization.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    https_get :index, params: credentials(format: :json)
    assert_response :success
    assert_equal presenter.list()[:data].to_json, @response.body
  end

  def test_index_xml_should_success
    program.organization.enable_feature(FeatureName::MENTORING_CONNECTIONS_V2)
    https_get :index, params: credentials(format: :xml)
    assert_response :success
    assert_equal presenter.list()[:data].to_xml(root: :mentoring_template), @response.body
  end


protected
  def presenter
    Api::V2::MentoringTemplatePresenter.new(program)
  end
end