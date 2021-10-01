require_relative './../../../test_helper.rb'

class Api::V2::UsersControllerTest < Api::V2::BasicControllerTest
  def setup
    super
    @target_member = members(:f_mentor)
    @presenter = Api::V2::UsersPresenter.new(@program, @program.organization)
  end

  # test security
  make_security_tests_for([
    [:get,    :index         ],
    [:post,   :create        ],
    [:put,    :update_status,  {uuid: 2, state: 2} ],
    [:delete, :destroy, id: 1]
  ])

  # not-found error handling
  make_not_found_tests_for([
    [:delete, :destroy]
  ])

  # index
  def test_index_json_should_success
    https_get :index, params: credentials(format: :json)
    assert_response :success
    assert_equal presenter.list[:data].to_json, @response.body
  end

  def test_index_xml_should_success
    https_get :index, params: credentials(format: :xml)
    assert_response :success
    assert_equal presenter.list[:data].to_xml(root: :users), @response.body
  end

  # create
  def test_create_should_success_if_valid_data_passed_as_xml
    # assert_difference "program.users.count", 1 do
    #   https_post :create, params: credentials(valid_user_params(format: "xml"))
    #   expect = { uuid: program.users.last.member.login_name }
    #   assert_response :success
    #   assert_equal expect.to_xml(root: :user), @response.body
    # end
  end

 # Commenting out this test for now
  # should be fixed: This test is passing only individually.
  def test_create_should_success_if_valid_data_passed_as_json
    # assert_difference "program.users.count", 1 do
    #   https_post :create, params: credentials(valid_user_params(format: "json"))
    #   expect = { uuid: program.users.last.member.login_name }
    #   assert_response :success
    #   assert_equal expect.to_json, @response.body
    # end
  end

  def test_create_should_be_404_if_invalid_data_passed_as_xml
    assert_no_difference "program.users.count" do
      https_post :create, params: credentials(invalid_user_params(format: "xml"))
      expect = ["user with uuid 'really-new-user-example' not found"]
      assert_response 404
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_be_404_if_invalid_data_passed_as_json
    assert_no_difference "program.users.count" do
      https_post :create, params: credentials(invalid_user_params(format: "json"))
      expect = ["user with uuid 'really-new-user-example' not found"]
      assert_response 404
      assert_equal expect.to_json, @response.body
    end
  end


  # update_status
  def test_update_status_should_return_correct_data
    admin = members(:f_admin)
    member = members(:f_mentor)
    https_put :update_status, params: credentials(format: :xml, uuid: member.id, status: 3)
    assert_response :success
    member.reload
    member.state = 0
    member.save
    result = @presenter.update_status({uuid: member.id, status: 3}, admin)
    assert_equal result[:data].to_xml(root: :user), @response.body

    https_put :update_status, params: credentials(format: :json, uuid: member.id, status: 0)
    assert_response :success
    member.reload
    member.state = 3
    member.save
    result = @presenter.update_status({uuid: member.id, status: 0}, admin)
    assert_equal result[:data].to_json, @response.body    
  end

  def test_update_status_should_return_404_on_member_not_found
    admin = members(:f_admin)
    member = members(:f_mentor)
    https_put :update_status, params: credentials(format: :xml, uuid: Member.last.id + 1, status: 3)
    expected_error = ["member with uuid '#{Member.last.id + 1}' not found"]
    result = @presenter.update_status({uuid: Member.last.id + 1, status: 3}, admin)
    assert_response :missing
    assert_equal expected_error.to_xml(root: :errors), @response.body

    https_put :update_status, params: credentials(format: :json, uuid: Member.last.id + 1, status: 2)
    assert_response :missing
    assert_equal expected_error.to_json, @response.body
  end

  def test_update_status_should_return_on_uuid_or_status_not_passed
    member = members(:f_mentor)
    https_put :update_status, params: credentials(format: :xml, status: 2)
    assert_response :missing
    expected_error = ["uuid not passed"]
    assert_equal expected_error.to_xml(root: :errors), @response.body

    https_put :update_status, params: credentials(format: :json, status: 2)
    assert_response :missing
    assert_equal expected_error.to_json(root: :errors), @response.body

    https_put :update_status, params: credentials(format: :xml, uuid: member.id)
    assert_response :missing
    expected_error = ["status not passed"]
    assert_equal expected_error.to_xml(root: :errors), @response.body

    https_put :update_status, params: credentials(format: :json, uuid: member.id)
    assert_response :missing
    assert_equal expected_error.to_json, @response.body
  end

  # destroy
  def test_destroy_should_success_as_xml
    assert_difference "program.users.count", -1 do
      https_delete :destroy, params: credentials(id: @target_member.id, format: "xml")
      assert_response :success
      expect = { uuid: @target_member.id }
      assert_equal expect.to_xml(root: :user), @response.body
    end
  end

  def test_destroy_should_success_as_json
    assert_difference "program.users.count", -1 do
      https_delete :destroy, params: credentials(id: @target_member.id, format: "json")
      assert_response :success
      expect = { uuid: @target_member.id }
      assert_equal expect.to_json, @response.body
    end
  end

protected
  def invalid_user_params(params = {})
    valid_user_params(params).merge(email: "really-new@user@example.com")
  end

  def valid_user_params(params = {})
    { uuid:       "really-new-user-example",
      email:      "really-new-user@example.com",
      first_name: "Really",
      last_name:  "New",
      roles:      "student",
    }.merge(params)
  end

  def presenter
    Api::V2::UsersPresenter.new(program)
  end
end
