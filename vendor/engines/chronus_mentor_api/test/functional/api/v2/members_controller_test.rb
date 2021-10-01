require_relative './../../../test_helper.rb'

class Api::V2::MembersControllerTest < Api::V2::BasicControllerTest

  def setup
    super
    admin = members(:f_admin)
    @organization = admin.organization
    @presenter = Api::V2::MembersPresenter.new(nil, @organization)
  end

  # test security
  make_security_tests_for([
    [:get, :index],
    [:get, :get_uuid, email: 'rahim@example.com'],
    [:get, :show,     id: 1],
    [:put, :update_status,  {uuid: 2, state: 2} ],
    [:delete, :destroy, id: 1],
    [:get, :profile_updates]
  ])

  # create
  def test_create_should_throw_error_on_missing_first_name_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(last_name: true, email: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_missing_last_name_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true, email: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors last_name: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_missing_email_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true, last_name: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors email: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_missing_first_name_last_name_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(email: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true, last_name: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_missing_first_name_email_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(last_name: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true, email: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_missing_last_name_email_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors last_name: true, email: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_no_params_xml
    assert_no_difference "organization.members.count" do
      params = {format: "xml"}
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true, last_name: true, email: true
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_throw_error_on_non_unique_email_xml
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true, last_name: true).merge(email: "ram@example.com", format: "xml")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = ["member with email_id: 'ram@example.com' already exists"]
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_show_correct_behaviour_on_correct_params_passed_xml
    assert_difference "organization.members.count", 1 do
      params = get_unique_params(first_name: true, last_name: true, email: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      member = organization.members.last
      expect = { uuid: member.id }
      assert_equal member.first_name, "first_name"
      assert_equal member.last_name, "last_name"
      assert_equal member.email, "unique_email@chronus.com"
      assert_response :success
      assert_equal expect.to_xml(root: :user), @response.body
    end
  end

  def test_create_should_show_correct_behaviour_on_correct_params_and_login_name_passed_xml
    custom_auth_1 = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    custom_auth_2 = organization.auth_configs.create!(auth_type: AuthConfig::Type::SOAP)

    assert_difference "organization.members.count", 1 do
      params = get_unique_params(first_name: true, last_name: true, email: true, login_name: true).merge(format: "xml")
      https_post :create, params: credentials(params)
      assert_response :success
      member = organization.members.last
      login_identifiers = member.login_identifiers
      expect = { uuid: member.id }
      assert_equal expect.to_xml(root: :user), @response.body
      assert_equal member.first_name, "first_name"
      assert_equal member.last_name, "last_name"
      assert_equal member.email, "unique_email@chronus.com"
      assert_equal ["login_name", "login_name"], login_identifiers.map(&:identifier)
      assert_equal_unordered [custom_auth_1, custom_auth_2], login_identifiers.map(&:auth_config)
    end
  end

  def test_create_should_throw_error_on_missing_first_name_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(last_name: true, email: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_missing_last_name_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true, email: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors last_name: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_missing_email_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true, last_name: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors email: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_missing_first_name_last_name_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(email: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true, last_name: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_missing_first_name_email_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(last_name: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true, email: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_missing_last_name_email_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors last_name: true, email: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_no_params_json
    assert_no_difference "organization.members.count" do
      params = {format: "json"}
      https_post :create, params: credentials(params)
      assert_response 404
      expect = get_errors first_name: true, last_name: true, email: true
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_throw_error_on_non_unique_email_json
    assert_no_difference "organization.members.count" do
      params = get_unique_params(first_name: true, last_name: true).merge(email: "ram@example.com", format: "json")
      https_post :create, params: credentials(params)
      assert_response 404
      expect = ["member with email_id: 'ram@example.com' already exists"]
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_show_correct_behaviour_on_correct_params_passed_json
    assert_difference "organization.members.count", 1 do
      params = get_unique_params(first_name: true, last_name: true, email: true).merge(format: "json")
      https_post :create, params: credentials(params)
      member = organization.members.last
      expect = { uuid: member.id }
      assert_equal member.first_name, "first_name"
      assert_equal member.last_name, "last_name"
      assert_equal member.email, "unique_email@chronus.com"
      assert_response :success
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_show_correct_behaviour_on_correct_params_and_login_name_passed_json
    custom_auth = organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)

    assert_difference "organization.members.count" do
      params = get_unique_params(first_name: true, last_name: true, email: true, login_name: true).merge(format: "json")
      https_post :create, params: credentials(params)
      assert_response :success
      member = organization.members.last
      login_identifiers = member.login_identifiers
      expect = { uuid: member.id }
      assert_equal expect.to_json, @response.body
      assert_equal member.first_name, "first_name"
      assert_equal member.last_name, "last_name"
      assert_equal member.email, "unique_email@chronus.com"
      assert_equal ["login_name"], login_identifiers.map(&:identifier)
      assert_equal [custom_auth], login_identifiers.map(&:auth_config)
    end
  end

  def test_index_json_success
    https_get :index, params: credentials(format: :json)
    assert_response :success
    assert_equal @presenter.list(members_list: 1)[:data].to_json, @response.body
  end

  def test_index_xml_success
    https_get :index, params: credentials(format: :xml)
    assert_response :success
    assert_equal @presenter.list(members_list: 1)[:data].to_xml(root: :users), @response.body
  end

  def test_index_json_success_with_created_after
    time_stamp = DateTime.localize(1.minute.ago.utc, format: :full_date_full_time)
    https_get :index, params: credentials(format: :json, created_after: time_stamp)
    assert_response :success
    assert_equal @presenter.list(members_list: 1, created_after: time_stamp)[:data].to_json, @response.body
  end

  def test_index_xml_success_with_created_after
    time_stamp = DateTime.localize(1.minute.ago.utc, format: :full_date_full_time)
    https_get :index, params: credentials(format: :xml, created_after: time_stamp)
    assert_response :success
    assert_equal @presenter.list(members_list: 1, created_after: time_stamp)[:data].to_xml(root: :users), @response.body
  end

  def test_profile_updates_json_success
    cur_time = Time.now
    https_get :profile_updates, params: credentials(format: :json, updated_after: cur_time)
    assert_response :success
    assert_equal @presenter.list(profile: 1, updated_after: cur_time)[:data].to_json, @response.body
  end

  def test_profile_updates_xml_success
    cur_time = Time.now
    https_get :profile_updates, params: credentials(format: :xml, updated_after: cur_time)
    assert_response :success
    assert_equal @presenter.list(profile: 1, updated_after: cur_time)[:data].to_xml(root: :users), @response.body
  end

  def test_profile_updates_json_success_without_created_after
    cur_time = Time.now
    https_get :profile_updates, params: credentials(format: :json, updated_after: cur_time, created_after: cur_time)
    assert_response :success
    assert_equal @presenter.list(profile: 1, updated_after: cur_time)[:data].to_json, @response.body
  end

  def test_profile_updates_xml_success_without_created_after
    cur_time = Time.now
    https_get :profile_updates, params: credentials(format: :xml, updated_after: cur_time, created_after: cur_time)
    assert_response :success
    assert_equal @presenter.list(profile: 1, updated_after: cur_time)[:data].to_xml(root: :users), @response.body
  end

  def test_get_uuid_should_return_404_if_no_email_id_or_login_name_passed
    https_get :get_uuid, params: credentials(format: :xml)
    expect_error = ["email or login_name not passed"]
    assert_response :missing
    assert_equal expect_error.to_xml(root: :errors), @response.body

    https_get :get_uuid, params: credentials(format: :json)
    assert_response :missing
    assert_equal expect_error.to_json(root: :errors), @response.body
  end


  def test_get_uuid_should_return_404_if_known_email_id_passed
    random_email = "some_random_email_id@example.com"
    https_get :get_uuid, params: credentials(format: :xml, email: random_email)
    expect_error = ["member with email #{random_email} not found"]
    assert_response :missing
    assert_equal expect_error.to_xml(root: :errors), @response.body

    https_get :get_uuid, params: credentials(format: :json, email: random_email)
    assert_response :missing
    assert_equal expect_error.to_json(root: :errors), @response.body
  end

  def test_destroy_should_return_correct_data_as_xml
    member = members(:f_mentor)
    https_delete :destroy, params: credentials(format: :xml, id: member)
    assert_response :success
    result = { uuid: member.id }
    assert_equal result.to_xml(root: :user), @response.body
  end

  def test_destroy_should_return_correct_data_as_json
    member = members(:f_mentor)
    result = { uuid: member.id }

    https_delete :destroy, params: credentials(format: :json, id: member)
    assert_response :success
    assert_equal result.to_json(root: :user), @response.body
  end

  def test_destroy_should_return_404_if_known_uuid_passed
    https_delete :destroy, params: credentials(format: :xml, id: 'random_id')
    expect_error = ["member with uuid random_id not found"]
    assert_response :missing
    assert_equal expect_error.to_xml(root: :errors), @response.body

    https_get :destroy, params: credentials(format: :json, id: 'random_id')
    assert_response :missing
    assert_equal expect_error.to_json(root: :errors), @response.body
  end

  def test_get_uuid_with_email_should_return_correct_data
    member = members(:f_mentor)
    https_get :get_uuid, params: credentials(format: :xml, email: member.email)
    assert_response :success
    result = {uuid: member.id}
    assert_equal result.to_xml(root: :uuid), @response.body

    https_get :get_uuid, params: credentials(format: :json, email: member.email)
    assert_response :success
    assert_equal result.to_json(root: :uuid), @response.body
  end

  def test_get_uuid_with_login_name_should_return_correct_data
    member = members(:f_mentor)
    custom_auth = member.organization.auth_configs.create!(auth_type: AuthConfig::Type::SAML)
    member.login_identifiers.create!(auth_config: custom_auth, identifier: "uid")

    https_get :get_uuid, params: credentials(format: :xml, login_name: "uid")
    assert_response :success
    result = { uuid: member.id }
    assert_equal result.to_xml(root: :uuid), @response.body

    https_get :get_uuid, params: credentials(format: :json, login_name: "uid")
    assert_response :success
    assert_equal result.to_json(root: :uuid), @response.body
  end

  def test_update_status_should_return_correct_data
    stub_parallel
    admin = members(:f_admin)
    member = members(:f_mentor)
    https_put :update_status, params: credentials(format: :xml, uuid: member.id, status: 2)
    assert_response :success
    member.reload
    member.reactivate!(admin)
    result = @presenter.update_status({uuid: member.id, status: 2}, admin)
    assert_equal result[:data].to_xml(root: :user), @response.body

    https_put :update_status, params: credentials(format: :json, uuid: member.id, status: 0)
    assert_response :success
    member.reload
    member.state = 2
    member.save
    result = @presenter.update_status({uuid: member.id, status: 0}, admin)
    assert_equal result[:data].to_json, @response.body
  end

  def test_update_status_should_return_404_on_member_not_found
    stub_parallel
    admin = members(:f_admin)
    member = members(:f_mentor)
    https_put :update_status, params: credentials(format: :xml, uuid: Member.last.id + 1, status: 2)
    expected_error = ["member with uuid '#{Member.last.id + 1}' not found"]
    result = @presenter.update_status({uuid: member.id, status: 2}, admin)
    assert_response :missing
    assert_equal expected_error.to_xml(root: :errors), @response.body

    https_put :update_status, params: credentials(format: :json, uuid: Member.last.id + 1, status: 2)
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

  def test_show_member_not_found
    https_get :show, params: credentials(format: :xml, id: (Member.last.id + 1))
    expect_error = ["user with uuid '#{Member.last.id + 1}' not found"]
    assert_response :missing
    assert_equal expect_error.to_xml(root: :errors), @response.body

    https_get :show, params: credentials(format: :json, id: (Member.last.id + 1))
    assert_response :missing
    assert_equal expect_error.to_json(root: :errors), @response.body
  end

  def test_show_member_success
    member = members(:f_mentor)
    https_get :show, params: credentials(format: :xml, id: member.id)
    expect_error = ["user with uuid '#{Member.last.id + 1}' not found"]
    assert_response :success
    data = @presenter.find(member.id)[:data]
    assert_equal data.to_xml(root: :user), @response.body

    https_get :show, params: credentials(format: :json, id: member.id)
    assert_response :success
    data = @presenter.find(member.id)[:data]
    assert_equal data.to_json, @response.body
  end

  private

  def get_errors(options)
    errors = []
    errors << "first name not passed" if options[:first_name]
    errors << "last name not passed" if options[:last_name]
    errors << "email not passed" if options[:email]
    errors
  end

  def get_unique_params(options)
    params = {}
    params[:first_name] = "first_name" if options[:first_name]
    params[:last_name] = "last_name" if options[:last_name]
    params[:email] = "unique_email@chronus.com" if options[:email]
    params[:login_name] = "login_name" if options[:login_name]
    params
  end
end