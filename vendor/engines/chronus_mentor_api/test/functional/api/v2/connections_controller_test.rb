require_relative './../../../test_helper.rb'

class Api::V2::ConnectionsControllerTest < Api::V2::BasicControllerTest
  def setup
    super
    # get group
    @groups = [groups(:mygroup), groups(:group_2)]
  end

  # test security
  make_security_tests_for([
    [:get,    :index         ],
    [:get,    :show,    id: 1],
    [:post,   :create        ],
    [:put,    :update,  id: 1],
    [:delete, :destroy, id: 1],
  ])

  # not-found error handling
  make_not_found_tests_for([
    [:get,    :show   ],
    [:put,    :update ],
    [:delete, :destroy],
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
    assert_equal presenter.list[:data].to_xml(root: :connections), @response.body
  end

  # show
  def test_show_json_should_success
    id = program.groups.first.id
    https_get :show, params: credentials(format: :json, id: id)
    assert_response :success
    assert_equal presenter.find(id)[:data].to_json, @response.body
  end

  def test_show_xml_should_success
    id = program.groups.first.id
    https_get :show, params: credentials(format: :xml, id: id)
    assert_response :success
    assert_equal presenter.find(id)[:data].to_xml(root: :connection), @response.body
  end

  # create
  def test_create_should_success_if_valid_data_passed_as_xml
    assert_difference "program.groups.count", 1 do
      https_post :create, params: credentials(valid_connection_params(format: "xml"))
      mentor_ids = program.organization.members.where(:email => valid_connection_params[:mentor_email]).collect(&:id)
      student_ids = program.organization.members.where(:email => valid_connection_params[:mentee_email]).collect(&:id)
      expect = { id: program.groups.last.id, mentor_ids: mentor_ids, student_ids: student_ids }
      assert_response :success
      assert_equal expect.to_xml(root: :connection), @response.body
    end
  end

  def test_create_should_success_if_valid_data_passed_as_json
    assert_difference "program.groups.count", 1 do
      https_post :create, params: credentials(valid_connection_params(format: "json"))
      mentor_ids = program.organization.members.where(:email => valid_connection_params[:mentor_email]).collect(&:id)
      student_ids = program.organization.members.where(:email => valid_connection_params[:mentee_email]).collect(&:id)
      expect = { id: program.groups.last.id, mentor_ids: mentor_ids, student_ids: student_ids }
      assert_response :success
      assert_equal expect.to_json, @response.body
    end
  end

  def test_create_should_be_404_if_invalid_data_passed_as_xml
    assert_no_difference "program.groups.count" do
      https_post :create, params: credentials(invalid_connection_params(format: "xml"))
      expect = ["user with email 'userrobert2@example.com' not found"]
      assert_response 404
      assert_equal expect.to_xml(root: :errors), @response.body
    end
  end

  def test_create_should_be_404_if_invalid_data_passed_as_json
    assert_no_difference "program.groups.count" do
      https_post :create, params: credentials(invalid_connection_params(format: "json"))
      expect = ["user with email 'userrobert2@example.com' not found"]
      assert_response 404
      assert_equal expect.to_json, @response.body
    end
  end

  # update
  def test_update_should_success_if_valid_data_passed_as_xml
    group = @groups[0]
    https_put :update, params: credentials(valid_connection_params(id: group.id, format: "xml"))
    group.reload # to be sure we have updated data
    assert group.students.map(&:email).include?("student_0@example.com")
    expect = presenter.find(group.id)[:data]
    assert_response :success
    assert_equal expect.to_xml(root: :connection), @response.body
  end

  def test_update_should_success_if_valid_data_passed_as_json
    group = @groups[0]
    https_put :update, params: credentials(valid_connection_params(id: group.id, format: "json"))
    group.reload # to be sure we have updated data
    assert group.students.map(&:email).include?("student_0@example.com")
    assert_response :success
    expect = presenter.find(group.id)[:data]
    assert_equal expect.to_json, @response.body
  end

  def test_update_should_render_404_if_invalid_data_passed_as_xml
    group = @groups[0]
    https_put :update, params: credentials(invalid_connection_params(id: group.id, format: "xml"))
    group.reload # to be sure we have updated data
    assert !group.students.map(&:email).include?("student_0@example.com")
    expect = ["user with email 'userrobert2@example.com' not found"]
    assert_response 404
    assert_equal expect.to_xml(root: :errors), @response.body
  end

  def test_update_should_render_404_if_invalid_data_passed_as_json
    group = @groups[0]
    https_put :update, params: credentials(invalid_connection_params(id: group.id, format: "json"))
    group.reload # to be sure we have updated data
    assert !group.students.map(&:email).include?("student_0@example.com")
    expect = ["user with email 'userrobert2@example.com' not found"]
    assert_response 404
    assert_equal expect.to_json, @response.body
  end

  # destroy
  def test_destroy_should_success_as_xml
    group = @groups[0]
    assert_difference "program.groups.count", -1 do
      https_delete :destroy, params: credentials(id: group.id, format: "xml")
      assert_response :success
      expect = { id: group.id }
      assert_equal expect.to_xml(root: :connection), @response.body
    end
  end

  def test_destroy_should_success_as_json
    group = @groups[0]
    assert_difference "program.groups.count", -1 do
      https_delete :destroy, params: credentials(id: group.id, format: "json")
      assert_response :success
      expect = { id: group.id }
      assert_equal expect.to_json, @response.body
    end
  end

protected
  def invalid_connection_params(params = {})
    valid_connection_params(params).merge(mentor_email: "userrobert2@example.com")
  end

  def valid_connection_params(params = {})
    { mentor_email: "userrobert@example.com",
      mentee_email: "student_0@example.com",
    }.merge(params)
  end

  def presenter
    Api::V2::ConnectionsPresenter.new(program)
  end
end
