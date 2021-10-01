require_relative './../test_helper.rb'

class ProjectRequestsControllerTest < ActionController::TestCase

  def test_login_required_for_new_project_request_form
    current_program_is :pbe
    get :new, params: { project_request: {from_page: :find_new}}
    assert_redirected_to new_session_path
  end

  def test_should_get_new_project_request_form_for_student
    current_user_is :f_student_pbe

    assert users(:f_student_pbe).can_send_project_request?

    get :new, params: { group_id: groups(:group_pbe_1).id, project_request: {from_page: :profile}}
    assert_response :success
    assert_template 'new'
    assert_equal :profile, assigns(:from_page)

    assert_select 'div.modal-header', count: 1 do
      assert_select 'h4', "Request to join #{groups(:group_pbe_1).name}"
    end
    assert_select 'div.modal-body', count: 1 do
      assert_select "input[type=hidden][name=?][value='#{groups(:group_pbe_1).id}']", 'project_request[group_id]'
    end
  end

  def test_should_get_new_project_request_form_for_teacher
    current_user_is :f_student_pbe
    group = groups(:group_pbe_1)

    users(:f_student_pbe).update_roles(["teacher"])
    assert_false users(:f_student_pbe).can_send_project_request?
    teacher_role = programs(:pbe).roles.find_by(name: "teacher")
    teacher_role.add_permission(RolePermission::SEND_PROJECT_REQUEST)

    get :new, params: { group_id: groups(:group_pbe_1).id, project_request: {from_page: :find_new}}
    assert_response :success
    assert_template 'new'
    assert_equal :find_new, assigns(:from_page)

    assert_select 'div.modal-header', count: 1 do
      assert_select 'h4', "Request to join #{groups(:group_pbe_1).name}"
    end
    assert_select 'div.modal-body', count: 1 do
      assert_select "input[type=hidden][name=?][value='#{groups(:group_pbe_1).id}']", 'project_request[group_id]'
    end
  end

  def test_should_get_permission_denied_for_new_project_request_form_for_teacher_without_permission
    current_user_is :f_student_pbe
    group = groups(:group_pbe_1)

    users(:f_student_pbe).update_roles(["teacher"])
    assert_false users(:f_student_pbe).can_send_project_request?
    teacher_role = programs(:pbe).roles.find_by(name: "teacher")
    assert_permission_denied do
      get :new, params: { group_id: groups(:group_pbe_1).id, project_request: {from_page: :find_new}}
    end
  end

  def test_should_not_get_new_project_request_form_for_mentor
    users(:f_mentor_pbe).program.roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    current_user_is :f_mentor_pbe
    assert_false users(:f_mentor_pbe).can_send_project_request?

    assert_permission_denied do
      get :new, params: { group_id: groups(:group_pbe_1).id, project_request: {from_page: :find_new}}
    end
  end

  def test_should_not_get_new_project_request_form_for_admin
    current_user_is :f_admin_pbe
    assert_false users(:f_admin_pbe).can_send_project_request?

    assert_permission_denied do
      get :new, params: { group_id: groups(:group_pbe_1).id, project_request: {from_page: :find_new}}
    end
  end

  def test_create_project_request_success
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_1)
    sender_role_id = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id

    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails 1 do
            assert_difference "ProjectRequest.count" do
              post :create, xhr: true, params: { project_request: {
                group_id: groups(:group_pbe_1).id,
                message: "Hi, This is request",
                sender_role_id: sender_role_id,
                from_page: :find_new
              }}
            end
          end
        end
      end
    end

    project_request = assigns(:project_request)
    assert_equal programs(:pbe), project_request.program
    assert_equal users(:f_student_pbe), project_request.sender
    assert_equal groups(:group_pbe_1), project_request.group
    assert_equal "Hi, This is request", project_request.message

    email = ActionMailer::Base.deliveries.last
    user = project_request.sender
    sender_name = user.name

    assert_equal "#{sender_name} requests to join the mentoring connection, #{group.name}", email.subject
    assert_equal [users(:f_admin_pbe).email], email.to
    mail_content = get_html_part_from(email)
    assert_match /p\/pbe\/groups\/#{group.id}\/profile/, mail_content
    assert_match /p\/pbe\/project_requests/, mail_content
    assert_match /If you must decline, please do so in a timely manner and be tactful./, mail_content

    project_request_ra = RecentActivity.last
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_SENT, project_request_ra.action_type
    assert_equal project_request, project_request_ra.ref_obj
    assert_equal project_request.group, connection_activity.group
    assert_equal t, connection_activity.group.last_activity_at

    assert_not_equal assigns(:from_page), :src_hpw
    assert_false assigns(:projects)
    assert_false assigns(:show_all_projects_option)
  end

  def test_create_request_from_home_page_widget
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_1)
    sender_role_id = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)

    post :create, xhr: true, params: { project_request: {
      group_id: groups(:group_pbe_1).id,
      message: "Hi, This is request",
      sender_role_id: sender_role_id,
      from_page: ProgramsController::SRC_HOME_PAGE_WIDGET
    }}

    assert_response :success
    assert_equal assigns(:from_page), :src_hpw
    assert_equal assigns(:projects), users(:f_student_pbe).available_projects_for_user.first
    assert_equal assigns(:show_all_projects_option), assigns(:projects).size > ProgramsController::MAX_PROJECTS_TO_SHOW_IN_HOME_PAGE_WIDGET
    assert_equal q, assigns(:connection_question)
    assert_equal_hash({}, assigns(:connection_question_answer_in_summary_hash))
  end

  def test_create_request_from_home_page_widget_with_any_connection_summary_q_answered
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_2)
    sender_role_id = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    q = Connection::Question.create(:program => programs(:pbe), :question_type => CommonQuestion::Type::STRING, :question_text => "Whats your age?")
    summary_q = Summary.create!(connection_question: q)
    ans = Connection::Answer.create!(
          :question => q,
          :group => groups(:group_pbe_2),
          :answer_text => 'hello')
    User.any_instance.stubs(:available_projects_for_user).returns([[groups(:group_pbe_2), groups(:group_pbe_1), groups(:group_pbe_3), groups(:group_pbe_4)], false])

    post :create, xhr: true, params: { project_request: {
      group_id: groups(:group_pbe_2).id,
      message: "Hi, This is request",
      sender_role_id: sender_role_id,
      from_page: ProgramsController::SRC_HOME_PAGE_WIDGET
    }}

    assert_response :success
    assert_equal q, assigns(:connection_question)
    assert_equal_hash({groups(:group_pbe_2).id => ans.answer_text}, assigns(:connection_question_answer_in_summary_hash))
  end

  def test_create_project_request_success_for_teacher
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_1)

    users(:f_student_pbe).update_roles(["teacher"])
    assert_false users(:f_student_pbe).can_send_project_request?
    teacher_role = programs(:pbe).roles.find_by(name: "teacher")
    teacher_role.add_permission(RolePermission::SEND_PROJECT_REQUEST)
    assert users(:f_student_pbe).reload.can_send_project_request?
    sender_role_id = programs(:pbe).roles.find_by(name: "teacher").id

    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails 1 do
            assert_difference "ProjectRequest.count" do
              post :create, xhr: true, params: { project_request: {
                group_id: groups(:group_pbe_1).id,
                message: "Hi, This is request for Teacher Role",
                sender_role_id: sender_role_id,
                from_page: :find_new
              }}
            end
          end
        end
      end
    end

    project_request = assigns(:project_request)
    assert_equal groups(:group_pbe_1), assigns(:group)
    assert_equal programs(:pbe), project_request.program
    assert_equal users(:f_student_pbe), project_request.sender
    assert_equal groups(:group_pbe_1), project_request.group
    assert_equal "Hi, This is request for Teacher Role", project_request.message

    email = ActionMailer::Base.deliveries.last
    user = project_request.sender
    sender_name = user.name

    assert_equal "#{sender_name} requests to join the mentoring connection, #{group.name}", email.subject
    assert_equal users(:f_admin_pbe).email, email.to.first
    mail_content = get_html_part_from(email)
    assert_match /p\/pbe\/groups\/#{group.id}\/profile/, mail_content
    assert_match /p\/pbe\/project_requests/, mail_content
    assert_match /If you must decline, please do so in a timely manner and be tactful./, mail_content

    project_request_ra = RecentActivity.last
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_SENT, project_request_ra.action_type
    assert_equal project_request, project_request_ra.ref_obj
    assert_equal project_request.group, connection_activity.group
    assert_equal t, connection_activity.group.last_activity_at
  end

  def test_should_not_create_new_project_request_by_mentor
    users(:f_mentor_pbe).program.roles.find_by(name: RoleConstants::MENTOR_NAME).remove_permission("send_project_request")
    current_user_is :f_mentor_pbe
    current_program_is :pbe

    assert_false users(:f_mentor_pbe).can_send_project_request?

    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: groups(:group_pbe_1).id, message: "sample message", from_page: :find_new}}
    end
  end

  def test_should_not_create_new_project_request_by_admin
    current_user_is :f_admin_pbe
    current_program_is :pbe

    assert_false users(:f_admin_pbe).can_send_project_request?

    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: groups(:group_pbe_1).id, message: "sample message", from_page: :find_new}}
    end
  end

  def test_should_not_create_new_project_request_by_teacher
    current_user_is :f_student_pbe
    current_program_is :pbe

    users(:f_student_pbe).update_roles(["teacher"])
    assert_false users(:f_student_pbe).can_send_project_request?

    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: groups(:group_pbe_1).id, message: "sample message", from_page: :find_new}}
    end
  end


  def test_create_or_new_project_request_fails_for_member_of_project
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe)

    assert group.has_member?(users(:f_student_pbe))
    assert_permission_denied do
      get :new, params: { group_id: group.id, project_request: {from_page: :find_new}}
    end
    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: group.id, message: "sample message", from_page: :find_new}}
    end
    assert_equal group, assigns(:group)
  end

  def test_create_or_new_project_request_fails_for_member_of_project_with_teacher_role
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe)
    group.students = []
    assert_false group.has_member?(users(:f_student_pbe))
    users(:f_student_pbe).add_role("teacher")
    teacher_role_id = programs(:pbe).roles.find_by(name: "teacher").id
    group.custom_memberships.create!(role_id: teacher_role_id, user_id: users(:f_student_pbe).id)
    assert group.has_member?(users(:f_student_pbe))

    assert_permission_denied do
      get :new, params: { group_id: group.id, project_request: {from_page: :find_new}}
    end
    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: group.id, message: "sample message", from_page: :find_new}}
    end
  end

  def test_create_or_new_project_request_for_published_project
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_1)
    program = group.program
    current_program_is :pbe

    group.publish(users(:f_admin_pbe), "test message")
    group.reload

    assert group.published?
    assert_nothing_raised do
      get :new, params: { group_id: group.id, project_request: {from_page: :find_new}}
    end

    student_role_id = program.roles.find_by(name: "student").id
    assert_nothing_raised do
      post :create, xhr: true, params: { project_request: {group_id: group.id, message: "sample message", sender_role_id: student_role_id, from_page: :find_new}}
    end
  end

  def test_create_or_new_permission_denied_for_proposed_project
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:proposed_group_1)

    assert_permission_denied do
      get :new, params: { group_id: group.id, project_request: {from_page: :find_new}}
    end
    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: group.id, message: "sample message", from_page: :find_new}}
    end
  end

  def test_create_or_new_project_request_with_student_max_limit
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_1) #already has 2 students
    set_max_limit_for_group(group, 2, RoleConstants::STUDENT_NAME)
    student_role_id = programs(:pbe).roles.find_by(name: "student").id

    assert_false group.available_roles_for_joining(student_role_id, additional_count: 1).present?
    assert_permission_denied do
      get :new, params: { group_id: group.id, project_request: {from_page: :find_new}}
    end
    assert_permission_denied do
      post :create, xhr: true, params: { project_request: {group_id: group.id, message: "sample message", sender_role_id: student_role_id, from_page: :find_new}}
    end

    set_max_limit_for_group(group, 10, RoleConstants::STUDENT_NAME)

    assert group.available_roles_for_joining(student_role_id, additional_count: 1).present?
    assert_nothing_raised do
      get :new, params: { group_id: group.id, project_request: {from_page: :find_new}}
    end
    assert_nothing_raised do
      post :create, xhr: true, params: { project_request: {group_id: group.id, message: "sample message", sender_role_id: student_role_id, from_page: :find_new}}
    end
  end

  def test_pending_project_requests
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe

    pending_requests = programs(:pbe).project_requests.active

    get :index, params: { track_publish_ga: "true", ga_src: "ga_src"}
    assert_response :success
    assert_template 'index'
    assert_select 'a#reset_filter_requestor'
    assert_select 'a#reset_filter_project'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(pending_requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
    assert assigns(:track_publish_ga)
    assert_equal "ga_src", assigns(:ga_src)
  end

  def test_pending_project_requests_with_filtered_group_ids_param
    @controller.stubs(:set_tile_data)
    @controller.instance_variable_set(:@project_request_hash,{})
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with(has_entry({page: 1}), {program: programs(:pbe), group_ids: ["27", "28", "29"]}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe

    pending_requests = programs(:pbe).project_requests.active

    get :manage, params: { filtered_group_ids: [27, 28, 29], from_bulk_publish: "true"}
    assert_response :success
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal ({"filtered_group_ids" => ["27", "28", "29"]}), assigns(:filter_params_to_store)
    paginated_requests = wp_collection_from_array(pending_requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
    assert_equal "The selected mentoring connections got published. There are few users who would like to join these mentoring connections. Please respond to the below requests as well.", flash[:notice]
  end

  def test_ajax_pending_project_requests_with_filtered_group_ids_param
    @controller.stubs(:set_tile_data)
    @controller.instance_variable_set(:@project_request_hash,{})
    program = programs(:pbe)
    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_filtered_project_requests).with(has_entry({ page: 1 }), { program: program, group_ids: ["27", "28", "29"] } ).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    pending_requests = program.project_requests.active

    current_user_is :f_admin_pbe
    get :manage, xhr: true, params: { filtered_group_ids: [27, 28, 29], from_bulk_publish: "true" }
    assert_response :success
    assert_nil flash[:notice]
    assert_equal wp_collection_from_array(pending_requests, 1).to_a, assigns(:project_requests).to_a
  end

  def test_ajax_pending_project_requests_with_filtered_group_ids_param_with_status
    @controller.stubs(:set_tile_data)
    @controller.instance_variable_set(:@project_request_hash,{})
    program = programs(:pbe)
    @controller.expects(:current_program).at_least(0).returns(program)
    time_now = Time.now.utc
    ProjectRequest.expects(:get_filtered_project_requests).with( {'status' => 'pending', 'start_time' => program.created_at.to_date, 'end_time' => time_now.to_date, 'page' => 1 }, { program: program, group_ids: ["27", "28", "29"] } ).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: 2))
    pending_requests = program.project_requests.active

    current_user_is :f_admin_pbe
    Timecop.freeze(time_now) do
      get :manage, xhr: true, params: { filtered_group_ids: [27, 28, 29], from_bulk_publish: "true", filters: { status: "pending"} }
    end
    assert_response :success
    assert_nil flash[:notice]
    assert_equal wp_collection_from_array(pending_requests, 1, 2).to_a, assigns(:project_requests).to_a
    assert_false assigns(:filter_params).is_a?(ActionController::Parameters)
  end


  def test_pending_project_requests_with_filtered_group_ids_param_single_group_publish
    published_group = groups(:group_pbe_0)
    program = published_group.program
    pending_requests = program.project_requests.active

    @controller.stubs(:set_tile_data)
    @controller.instance_variable_set(:@project_request_hash,{})
    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_filtered_project_requests).with(has_entry({ page: 1 }), { program: program, group_ids: ["#{published_group.id}"]}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is :f_admin_pbe
    get :manage, params: { filtered_group_ids: [published_group.id], from_bulk_publish: "false" }
    assert_response :success
    assert_equal 1, assigns(:filter_params)[:page]

    paginated_requests = wp_collection_from_array(pending_requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
    assert_equal "Congratulations on publishing <a href=\"#{profile_group_url(published_group)}\">project_a</a>! There are outstanding request(s) to join your mentoring connection. Please respond below.", flash[:notice]
  end

  def test_pending_project_requests_with_filtered_group_ids_param_and_dont_show_flash
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe), group_ids: ["27"]}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe

    pending_requests = programs(:pbe).project_requests.active

    get :index, params: { :filtered_group_ids => [27], from_bulk_publish: "false", dont_show_flash: true}
    assert_response :success
    assert_template 'index'
    assert_select 'a#reset_filter_requestor'
    assert_select 'a#reset_filter_project'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(pending_requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
    assert_nil flash[:notice]
  end

  def test_ajax_pending_project_requests_with_filtered_group_ids_param_single_group_publish
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe), group_ids: ["27"]}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe

    pending_requests = programs(:pbe).project_requests.active

    get :index, xhr: true, params: { :filtered_group_ids => [27], from_bulk_publish: "false"}
    assert_response :success
    paginated_requests = wp_collection_from_array(pending_requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert_nil flash[:notice]
  end

  def test_rejected_project_requests
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"status"=>"declined", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [22, 23, 24, 25, 26]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe

    rejected_requests = programs(:pbe).project_requests.rejected

    get :index, params: { filters: {status: 'declined'}}
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(rejected_requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_project_filter_for_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"project"=>"project_c", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [29]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe
    get :index, params: { filters: {project: "project_c"}, from_quick_link: true}
    assert_response :success
    assert_template 'index'
    assert_equal [groups(:group_pbe_2).id], assigns(:project_requests).collect(&:group_id)
    assert_equal "Mentoring Connections", assigns(:back_link)[:label]
  end

  def test_project_filter_for_admin_with_back_link
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"project"=>"project_c", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [29]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe
    get :index, params: { filters: {project: "project_c"}, from_quick_link: true, from_profile: true}
    assert_response :success
    assert_template 'index'
    assert_equal [groups(:group_pbe_2).id], assigns(:project_requests).collect(&:group_id)
    assert_equal "project_c", assigns(:back_link)[:label]
  end

  def test_sender_filter_for_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"requestor"=>"student_c", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is :f_admin_pbe
    current_program_is :pbe
    get :index, params: { filters: {requestor: "student_c"}}
    assert_response :success
    assert_template 'index'
    assert_equal [users(:pbe_student_2).id], assigns(:project_requests).collect(&:sender_id)
  end

  def test_invalid_sender_filter_for_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"requestor"=>"sdnvcadjksfsk", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: []).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    current_program_is :pbe
    get :index, params: { filters: {requestor: "sdnvcadjksfsk"}}
    assert_response :success
    assert_template 'index'
    assert_equal 0, assigns(:project_requests).size
  end

  def test_date_filter_for_admin_empty
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    current_user_is :f_admin_pbe
    current_program_is :pbe
    ProjectRequest.expects(:get_filtered_project_requests).with({"start_time" => 30.days.ago.beginning_of_day.to_datetime, "end_time" => 2.days.ago.end_of_day.to_datetime, "page" => 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: []).paginate(page: 1, per_page: PER_PAGE))

    get :index, params: { filters: {sent_between: "#{30.days.ago.strftime("%m/%d/%Y")} - #{2.days.ago.strftime("%m/%d/%Y")}"}}
    assert_response :success
    assert_template 'index'
    assert_equal 0, assigns(:project_requests).size
  end

  def test_date_filter_for_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    current_user_is :f_admin_pbe
    current_program_is :pbe
    ProjectRequest.expects(:get_filtered_project_requests).with({"start_time" => 30.days.ago.beginning_of_day.to_datetime, "end_time" => 2.days.from_now.end_of_day.to_datetime, "page" => 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    get :index, params: { filters: {sent_between: "#{30.days.ago.strftime("%m/%d/%Y")} - #{2.days.from_now.strftime("%m/%d/%Y")}"}}
    assert_response :success
    assert_false assigns(:project_request_view)
    assert_template 'index'
    assert_equal 5, assigns(:project_requests).size
  end

  def test_request_view_for_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"status"=>"pending", "requestor"=>nil, "project"=>nil, "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    view = ProjectRequestView::DefaultViews.create_for(programs(:pbe))[0]

    get :index, params: { :view_id => view.id}
    assert_response :success
    assert_equal_hash({status: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED].to_s, project: nil, requestor: nil, :page=>1}, assigns(:filter_params))
    assert_equal "Mentoring Connection Requests", assigns(:title)
    assert assigns(:project_request_view)
    assert_equal_hash({:label => "feature.reports.content.dashboard".translate, :link => management_report_path}, assigns(:back_link))
    assert_equal 5, assigns(:project_requests).size
  end

  def test_request_view_for_admin_with_filters
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"status"=>"pending", "requestor"=>nil, "project"=>"ABC", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: []).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    view = ProjectRequestView::DefaultViews.create_for(programs(:pbe))[0]

    get :index, params: { :view_id => view.id, :filters => {:project => "ABC"}}
    assert_response :success
    assert_equal_hash({status: AbstractRequest::Status::STATE_TO_STRING[AbstractRequest::Status::NOT_ANSWERED].to_s, project: "ABC", requestor: nil, :page=>1}, assigns(:filter_params))
    assert_equal "Mentoring Connection Requests", assigns(:title)
    assert assigns(:project_request_view)
    assert_equal_hash({:label => "feature.reports.content.dashboard".translate, :link => management_report_path}, assigns(:back_link))
    assert_equal 0, assigns(:project_requests).size
  end

  def test_end_user_cant_access_all_project_requests
    student_user = users(:pbe_student_2)
    program = student_user.program

    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_filtered_project_requests).with( { page: 1 }, program: program, sender_id: student_user.id).returns(ProjectRequest.where(id: 27).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:project_requests).size
  end

  def test_select_all_ids_permission_denied
    student_user = users(:pbe_student_2)
    assert_false student_user.can_manage_project_requests?

    current_user_is student_user
    assert_permission_denied { get :select_all_ids }
  end

  def test_select_all_ids_without_filters
    program = programs(:pbe)
    pending_requests = program.project_requests.active

    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_project_request_ids).with( { page: 1 }, { program: program } ).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).pluck(:id).map(&:to_s))
    current_user_is :f_admin_pbe
    get :select_all_ids
    assert_response :success
    assert_empty assigns(:my_filters)
    assert_equal_hash( { "page" =>1 }, assigns(:filter_params))
    assert_equal_unordered pending_requests.collect(&:id).map(&:to_s), JSON.parse(response.body)["project_request_ids"]
  end

  def test_select_all_ids_with_filters
    program = programs(:pbe)
    rejected_requests = program.project_requests.rejected

    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_project_request_ids).with( { "status" => "declined", "start_time" => "", "end_time" => "", "page" => 1 }, { program: program } ).returns(ProjectRequest.where(id: [22, 23, 24, 25, 26]).pluck(:id).map(&:to_s))
    current_user_is :f_admin_pbe
    get :select_all_ids, params: { filters: { status: "declined" } }
    assert_response :success
    assert_equal_unordered [{label: "Status", reset_suffix: "status"}], assigns(:my_filters)
    assert_equal_hash( { "status" => "declined", "start_time" => "", "end_time" => "", "page" => 1 }, assigns(:filter_params))
    assert_equal_unordered rejected_requests.collect(&:id).map(&:to_s), JSON.parse(response.body)["project_request_ids"]
  end

  def test_update_invalid_id
    current_user_is :f_admin_pbe
    assert_nothing_raised do
      put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: 0 }
    end
    assert_response :success
    assert_blank assigns(:project_requests)
  end

  def test_update_non_active_request
    admin = users(:f_admin_pbe)
    program = admin.program
    project_request = program.project_requests.active.first
    project_request.mark_accepted(admin)

    current_user_is admin
    assert_nothing_raised do
      put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: project_request.id}
    end
    assert_equal AbstractRequest::Status::REJECTED, assigns(:status)
    assert_response :success
    assert project_request.reload.accepted?
    assert_false assigns(:project_requests).present?
  end

  def test_accept_project_request_permission_denied
    current_user_is :pbe_student_2
    current_program_is :pbe

    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_permission_denied do
      put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: programs(:pbe).project_requests.active.first.id}
    end
  end

  def test_bulk_accept_project_request_permission_denied
    current_user_is :pbe_student_2
    current_program_is :pbe
    ids = programs(:pbe).project_requests.active.collect(&:id).join(",")

    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_permission_denied do
      post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: ids, bulk_action: true}
    end
  end

  def test_bulk_reject_project_request_permission_denied
    current_user_is :pbe_student_2
    current_program_is :pbe
    ids = programs(:pbe).project_requests.active.collect(&:id).join(",")

    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_permission_denied do
      post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: ids, bulk_action: true}
    end
  end

  def test_bulk_reject_project_request
    current_user_is :f_admin_pbe
    current_program_is :pbe
    ids = programs(:pbe).project_requests.active.collect{|r| r.id.to_s}
    assert users(:f_admin_pbe).can_manage_project_requests?
    ProjectRequest.where(id: ids).each do |project_request|
      Push::Base.expects(:queued_notify).with(PushNotification::Type::PBE_CONNECTION_REQUEST_REJECT, project_request).once
    end

    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count", ids.size do
        assert_difference "Connection::Activity.count", ids.size do
          assert_emails ids.size do
            post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: ids.join(","), bulk_action: true, is_manage_view: true,
              project_request: {
                response_text: "Rejecting all requests"
              }
            }
          end
        end
      end
    end

    recent_activities = RecentActivity.last(ids.size)
    recent_activities.each do |project_request_ra|
      assert_equal 1, project_request_ra.connection_activities.count
      connection_activity = project_request_ra.connection_activities.last
      assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
      assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_REJECTED, project_request_ra.action_type
      project_request = project_request_ra.ref_obj
      assert_equal project_request.group, connection_activity.group
      assert_equal t, connection_activity.group.last_activity_at
    end

    assert_equal "The selected mentoring connection requests have been rejected.", assigns(:flash_notice)
    assert_nil assigns(:flash_error)
    assert assigns(:is_manage_view)
    assert_equal ids.map(&:to_i), assigns(:project_requests).map(&:id)
  end

  def test_accept_project_request
    current_user_is :f_admin_pbe
    current_program_is :pbe
    group = groups(:group_pbe)
    project_request = create_project_request(group, users(:pbe_student_1))

    Group.any_instance.stubs(:reached_critical_mass?).returns(true)
    Group.expects(:create_tasks_for_added_memberships).once
    Group.any_instance.stubs(:has_future_start_date?).returns(false)

    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails 1 do
            put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: project_request.id.to_s}
          end
        end
      end
    end
    assert_nil assigns(:flash_error)
    assert_equal [project_request.id], assigns(:project_requests).map(&:id)

    project_request_ra = RecentActivity.last
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED, project_request_ra.action_type
    project_request = project_request_ra.ref_obj
    assert_equal project_request.group, connection_activity.group
    assert_equal t, connection_activity.group.last_activity_at
    assert_equal project_request.group, assigns(:critical_mass_group)
  end

  def test_accept_project_request_with_group_automatically_starting
    current_user_is :f_admin_pbe
    current_program_is :pbe
    group = groups(:group_pbe)
    project_request = create_project_request(group, users(:pbe_student_1))

    Group.any_instance.stubs(:reached_critical_mass?).returns(true)
    Group.expects(:create_tasks_for_added_memberships).once
    Group.any_instance.stubs(:has_future_start_date?).returns(true)

    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails 1 do
            put :update_actions, xhr: true, params: {request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: project_request.id.to_s}
          end
        end
      end
    end
  
    assert_false assigns(:critical_mass_group)
  end

  def test_accept_without_default_tasks
    current_user_is :f_admin_pbe
    current_program_is :pbe
    group = groups(:group_pbe)
    project_request = create_project_request(group, users(:pbe_student_1))

    Group.expects(:create_tasks_for_added_memberships).never
    put :update_actions, xhr: true, params: {
        request_type: AbstractRequest::Status::ACCEPTED,
        project_request_ids: project_request.id.to_s,
        project_request: { add_member_option: Group::AddOption::NO_TASK }
      }

    assert_response :success
  end

  def test_bulk_accept_project_request
    current_user_is :f_admin_pbe
    current_program_is :pbe
    ids = programs(:pbe).project_requests.active.collect{|r| r.id.to_s}
    assert users(:f_admin_pbe).can_manage_project_requests?

    assert_difference "RecentActivity.count", ids.size do
      assert_difference "Connection::Activity.count", ids.size do
        assert_emails ids.size do
          post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: ids.join(","), bulk_action: true}
        end
      end
    end

    assert_equal "The selected mentoring connection requests have been accepted.", assigns(:flash_notice)
    assert_nil assigns(:flash_error)
    assert_equal ids.map(&:to_i), assigns(:project_requests).map(&:id)
  end

  def test_accept_project_request_when_no_student_slots
    current_user_is :f_admin_pbe
    current_program_is :pbe
    request = programs(:pbe).project_requests.active.first
    set_max_limit_for_group(request.group, 1, RoleConstants::STUDENT_NAME)

    assert users(:f_admin_pbe).can_manage_project_requests?
    assert_no_emails do
      put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: request.id, bulk_action: true}
    end

    assert_equal "Request not accepted because <b>#{request.group.name}</b> exceeded maximum limit", assigns(:flash_error)
    assert_nil assigns(:flash_notice)
    assert_equal [request.id], assigns(:project_requests).map(&:id)
  end

  def test_bulk_accept_project_request_when_sender_already_in_project
    current_user_is :f_admin_pbe
    current_program_is :pbe
    group = groups(:group_pbe_2)
    student_user = users(:pbe_student_5)
    request = create_project_request(group, student_user)
    student_user.add_role(RoleConstants::MENTOR_NAME)
    group.update_members(group.mentors + [student_user], group.students)

    assert users(:f_admin_pbe).can_manage_project_requests?
    assert_no_emails do
      post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: "#{request.id}"}
    end
    assert_equal "<b>#{request.sender.name}</b> is already part of <b>#{request.group.name}</b>", assigns(:flash_error)
    assert_nil assigns(:flash_notice)
    assert_equal [request.id], assigns(:project_requests).map(&:id)
  end

  def test_index_from_owner_and_admin
    student_user = users(:pbe_student_2)
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    student_user.roles.first.remove_permission("send_project_request")
    student_user.add_role(RoleConstants::ADMIN_NAME)
    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.project_manager_or_owner?

    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.has_owned_groups?
    requests = student_user.sent_project_requests.active

    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view"=>"1", "start_time"=>"", "end_time"=>"", "page"=>1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index, params: { filters: { view: ProjectRequest::VIEW::FROM } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_from_only_owner
    student_user = users(:pbe_student_2)
    student_user.roles.first.remove_permission("send_project_request")
    assert_false student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    requests = student_user.sent_project_requests.active
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    assert student_user.project_manager_or_owner?

    ProjectRequest.expects(:get_filtered_project_requests).with( { "view"=>"1", "start_time"=>"", "end_time"=>"", "page"=>1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    current_user_is student_user
    get :index, params: { filters: {view: ProjectRequest::VIEW::FROM } }
    assert_response :success
    assert_template 'index'
    assert_select 'a#reset_filter_requestor'
    assert_select 'a#reset_filter_project'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_from_owner_admin_and_sender
    student_user = users(:pbe_student_2)
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    student_user.add_role(RoleConstants::ADMIN_NAME)
    assert student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.project_manager_or_owner?

    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    assert student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.has_owned_groups?
    requests = student_user.sent_project_requests.active

    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view"=>"1", "start_time"=>"", "end_time"=>"", "page"=>1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index, params: { filters: { view: ProjectRequest::VIEW::FROM } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_from_owner_and_sender
    student_user = users(:pbe_student_2)
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    requests = student_user.sent_project_requests.active
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    assert student_user.project_manager_or_owner?

    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view"=>"1", "start_time"=>"", "end_time"=>"", "page"=>1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index, params: { filters: { view: ProjectRequest::VIEW::FROM } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_to_owner_and_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"view"=>"0", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)

    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    student_user.roles.first.remove_permission("send_project_request")
    student_user.add_role(RoleConstants::ADMIN_NAME)

    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.project_manager_or_owner?

    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)

    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.has_owned_groups?

    requests = programs(:pbe).project_requests.active
    get :index, params: { filters: {view: ProjectRequest::VIEW::TO}}
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?

    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_to_only_owner
    student_user = users(:pbe_student_2)
    current_user_is student_user
    program = student_user.program
    student_user.roles.first.remove_permission("send_project_request")
    assert_false student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    group = groups(:group_pbe_2)
    student_requests = student_user.sent_project_requests.active
    requests = group.project_requests.active
    assert_not_equal student_requests, requests
    group.membership_of(student_user).update_attributes!(owner: true)
    assert student_user.project_manager_or_owner?

    ProjectRequest.expects(:get_filtered_project_requests).with( { "view" => "0", "start_time" => "", "end_time" => "", "page" => 1 }, { program: program, group_ids: [group.id] } ).returns(ProjectRequest.where(id: [29]).paginate(page: 1, per_page: PER_PAGE))
    get :index, params: { filters: { view: ProjectRequest::VIEW::TO } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal wp_collection_from_array(requests, 1).to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?

    ProjectRequest.expects(:get_filtered_project_requests).with( { page: 1 }, { program: program, group_ids: [group.id] } ).returns(ProjectRequest.where(id: [29]).paginate(page: 1, per_page: PER_PAGE))
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal wp_collection_from_array(requests, 1).to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_to_owner_admin_and_sender
    student_user = users(:pbe_student_2)
    program = student_user.program
    requests = program.project_requests.active
    group = groups(:group_pbe_2)
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    student_user.roles.first.remove_permission("send_project_request")
    student_user.add_role(RoleConstants::ADMIN_NAME)
    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.project_manager_or_owner?
    group.membership_of(student_user).update_attributes!(owner: true)
    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.has_owned_groups?

    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view" => "0", "start_time" => "", "end_time" => "", "page" => 1 }, { program: program } ).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is :pbe_student_2
    get :index, params: { filters: { view: ProjectRequest::VIEW::TO } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal wp_collection_from_array(requests, 1).to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?

    ProjectRequest.expects(:get_filtered_project_requests).with( { page: 1 }, { program: program } ).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal wp_collection_from_array(requests, 1).to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_to_owner_and_sender
    student_user = users(:pbe_student_2)
    program = student_user.program
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    group = groups(:group_pbe_2)
    requests = group.project_requests.active
    group.membership_of(student_user).update_attributes!(owner: true)
    assert student_user.project_manager_or_owner?

    @controller.expects(:current_program).at_least(0).returns(program)
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view" => "0", "start_time" => "", "end_time" => "", "page" => 1 }, { program: program, group_ids: [group.id] } ).returns(ProjectRequest.where(id: [29]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index, params: { filters: {view: ProjectRequest::VIEW::TO } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal wp_collection_from_array(requests, 1).to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?

    ProjectRequest.expects(:get_filtered_project_requests).with( { page: 1 }, { program: program, group_ids: [group.id] } ).returns(ProjectRequest.where(id: [29]).paginate(page: 1, per_page: PER_PAGE))
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    assert_equal wp_collection_from_array(requests, 1).to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_to_only_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({"view"=>"0", "start_time"=>"", "end_time"=>"", "page"=>1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)

    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    student_user.roles.first.remove_permission("send_project_request")
    student_user.add_role(RoleConstants::ADMIN_NAME)

    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.project_manager_or_owner?
    assert_false student_user.has_owned_groups?

    requests = programs(:pbe).project_requests.active
    get :index, params: { filters: {view: ProjectRequest::VIEW::TO}}
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?

    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_from_only_admin
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    current_user_is :pbe_student_2
    current_program_is :pbe
    student_user = users(:pbe_student_2)

    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?

    student_user.roles.first.remove_permission("send_project_request")
    student_user.add_role(RoleConstants::ADMIN_NAME)

    assert_false student_user.can_send_project_request?
    assert student_user.can_manage_project_requests?
    assert student_user.project_manager_or_owner?
    assert_false student_user.has_owned_groups?

    ProjectRequest.expects(:get_filtered_project_requests).with({"view" => "1", "start_time" => "", "end_time" => "", "page" => 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    requests = programs(:pbe).project_requests.active
    get :index, params: { filters: {view: ProjectRequest::VIEW::FROM}}
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_to_only_sender
    student_user = users(:pbe_student_2)
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?
    assert_false student_user.has_owned_groups?
    requests = student_user.sent_project_requests.active

    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view"=>"0", "start_time"=>"", "end_time"=>"", "page"=>1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index, params: { filters: { view: ProjectRequest::VIEW::TO } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?

    ProjectRequest.expects(:get_filtered_project_requests).with( { page: 1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_from_only_sender
    student_user = users(:pbe_student_2)
    assert student_user.can_send_project_request?
    assert_false student_user.can_manage_project_requests?
    assert_false student_user.project_manager_or_owner?
    assert_false student_user.has_owned_groups?
    requests = student_user.sent_project_requests.active

    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with( { "view"=>"1", "start_time"=>"", "end_time"=>"", "page"=>1 }, program: programs(:pbe), sender_id: student_user.id).returns(ProjectRequest.where(id: [27]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is student_user
    get :index, params: { filters: { view: ProjectRequest::VIEW::FROM } }
    assert_response :success
    assert_template 'index'
    assert_equal 1, assigns(:filter_params)[:page]
    paginated_requests = wp_collection_from_array(requests, 1)
    assert_equal paginated_requests.to_a, assigns(:project_requests).to_a
    assert assigns(:title).present?
  end

  def test_index_with_src
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))

    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    get :index, params: { :src => ReportConst::ManagementReport::SourcePage}
    assert_response :success
    assert_equal ReportConst::ManagementReport::SourcePage, assigns(:src_path)
  end

  def test_index_no_src
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))
    current_user_is :f_admin_pbe
    get :index
    assert_response :success
    assert_nil assigns(:src_path)
  end

  def test_create_project_request_should_notify_owner
    current_user_is :f_student_pbe
    current_program_is :pbe
    group = groups(:group_pbe_1)
    sender_role_id = programs(:pbe).roles.find_by(name: RoleConstants::STUDENT_NAME).id
    groups(:group_pbe_1).membership_of(users(:pbe_student_1)).update_attributes!(owner: true)

    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails 2 do
            assert_difference "ProjectRequest.count" do
              post :create, xhr: true, params: { project_request: {
                group_id: groups(:group_pbe_1).id,
                message: "Hi, This is request",
                sender_role_id: sender_role_id,
                from_page: :find_new
              }}
            end
          end
        end
      end
    end

    project_request = assigns(:project_request)
    assert_equal programs(:pbe), project_request.program
    assert_equal users(:f_student_pbe), project_request.sender
    assert_equal groups(:group_pbe_1), project_request.group
    assert_equal "Hi, This is request", project_request.message

    emails = ActionMailer::Base.deliveries.last(2)
    email = emails.last
    user = project_request.sender
    sender_name = user.name

    assert_equal "#{sender_name} requests to join the mentoring connection, #{group.name}", email.subject
    assert_equal_unordered [users(:f_admin_pbe).email, users(:pbe_student_1).email], emails.collect(&:to).flatten
    mail_content = get_html_part_from(email)
    assert_match /p\/pbe\/groups\/#{group.id}\/profile/, mail_content
    assert_match /p\/pbe\/project_requests/, mail_content
    assert_match /If you must decline, please do so in a timely manner and be tactful./, mail_content

    project_request_ra = RecentActivity.last
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_SENT, project_request_ra.action_type
    assert_equal project_request, project_request_ra.ref_obj
    assert_equal project_request.group, connection_activity.group
    assert_equal t, connection_activity.group.last_activity_at
  end

  def test_owner_should_be_able_to_accept_owned_project_request
    current_user_is :pbe_student_2
    current_program_is :pbe

    student_user = users(:pbe_student_2)
    assert_false student_user.can_manage_project_requests?
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    assert student_user.has_owned_groups?
    assert student_user.project_manager_or_owner?

    id = groups(:group_pbe_2).project_requests.active.first.id
    t = Time.new(2012)
    Timecop.freeze(t) do
      assert_difference "RecentActivity.count" do
        assert_difference "Connection::Activity.count" do
          assert_emails 1 do
            put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: id}
          end
        end
      end
    end
    assert_response :success

    assert_equal "The selected mentoring connection request has been accepted.", assigns(:flash_notice)
    assert_nil assigns(:flash_error)
    assert_equal [id], assigns(:project_requests).map(&:id)

    project_request_ra = RecentActivity.last
    assert_equal 1, project_request_ra.connection_activities.count
    connection_activity = project_request_ra.connection_activities.last
    assert_equal RecentActivityConstants::Target::NONE, project_request_ra.target
    assert_equal RecentActivityConstants::Type::PROJECT_REQUEST_ACCEPTED, project_request_ra.action_type
    project_request = project_request_ra.ref_obj
    assert_equal project_request.group, connection_activity.group
    assert_equal t, connection_activity.group.last_activity_at
  end

  def test_owner_should_not_be_able_to_accept_other_project_request
    current_user_is :pbe_student_2
    current_program_is :pbe

    student_user = users(:pbe_student_2)
    assert_false student_user.can_manage_project_requests?
    groups(:group_pbe_2).membership_of(student_user).update_attributes!(owner: true)
    id = groups(:group_pbe_1).project_requests.active.first.id

    assert student_user.has_owned_groups?
    assert student_user.project_manager_or_owner?
    assert_false student_user.is_owner_of?(groups(:group_pbe_1))
    assert_permission_denied do
      put :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: id}
    end
  end


  def test_select_all_ids_for_owner
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_project_request_ids).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).pluck(:id).map(&:to_s))

    current_user_is :pbe_student_2
    current_program_is :pbe
    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_false users(:pbe_student_2).project_manager_or_owner?
    groups(:group_pbe_2).membership_of(users(:pbe_student_2)).update_attributes!(owner: true)
    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert users(:pbe_student_2).project_manager_or_owner?

    get :select_all_ids
    assert_response :success
  end

  def test_fetch_actions_email_notification_text_shown_to_admin_user
    current_user_is :f_admin
    current_program_is :pbe

    id = programs(:pbe).project_requests.active.first.id
    post :fetch_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: [id]}
    assert_equal AbstractRequest::Status::ACCEPTED, assigns(:status)
    assert_response :success
    assert_select "p.help-block", text: /An email will be sent to the user if you complete this action./
    assert_match /#{ProjectRequestAccepted.mailer_attributes[:uid]}/, response.body

    post :fetch_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: [id]}
    assert_response :success
    assert_select "p.help-block", text: /An email will be sent to the selected user, with the reason for rejecting/
    assert_match /#{ProjectRequestRejected.mailer_attributes[:uid]}/, response.body
  end

  def test_fetch_actions_for_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    ids = programs(:pbe).project_requests.active.collect(&:id)
    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_false users(:pbe_student_2).project_manager_or_owner?
    groups(:group_pbe_2).membership_of(users(:pbe_student_2)).update_attributes!(owner: true)
    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert users(:pbe_student_2).project_manager_or_owner?

    post :fetch_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: ids}
    assert_response :success
    assert_select "p.help-block", text: /An email will be sent to the user if you complete this action./, count: 0

    post :fetch_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: ids}
    assert_response :success
    assert_select "p.help-block", text: /An email will be sent to the selected user, with the reason for rejecting/, count: 0
  end

  def test_update_actions_accept_for_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    programs(:pbe).project_requests.update_all(status: AbstractRequest::Status::NOT_ANSWERED)

    ids = groups(:group_pbe_2).project_requests.active.collect(&:id).join(",")

    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_false users(:pbe_student_2).project_manager_or_owner?
    groups(:group_pbe_2).membership_of(users(:pbe_student_2)).update_attributes!(owner: true)
    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert users(:pbe_student_2).project_manager_or_owner?

    post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: ids, bulk_action: true}
    assert_response :success

    assert_equal [AbstractRequest::Status::ACCEPTED], groups(:group_pbe_2).project_requests.collect(&:status).uniq

    programs(:pbe).project_requests.update_all(status: AbstractRequest::Status::NOT_ANSWERED)

    ids = (groups(:group_pbe_2).project_requests.active.collect(&:id) + groups(:group_pbe_1).project_requests.active.collect(&:id)).join(",")
    assert_permission_denied do
      post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::ACCEPTED, project_request_ids: ids, bulk_action: true}
    end
    assert_equal [AbstractRequest::Status::NOT_ANSWERED], programs(:pbe).project_requests.collect(&:status).uniq
  end

  def test_update_actions_reject_for_owner
    current_user_is :pbe_student_2
    current_program_is :pbe
    programs(:pbe).project_requests.update_all(status: AbstractRequest::Status::NOT_ANSWERED)

    ids = groups(:group_pbe_2).project_requests.active.collect(&:id).join(",")

    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert_false users(:pbe_student_2).project_manager_or_owner?
    groups(:group_pbe_2).membership_of(users(:pbe_student_2)).update_attributes!(owner: true)
    assert_false users(:pbe_student_2).can_manage_project_requests?
    assert users(:pbe_student_2).project_manager_or_owner?

    post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: ids, bulk_action: true,
      project_request: {
        response_text: "Rejecting all requests"
      }
    }
    assert_equal "Rejecting all requests", assigns(:response_text)
    assert_response :success

    assert_equal [AbstractRequest::Status::REJECTED], groups(:group_pbe_2).project_requests.collect(&:status).uniq

    programs(:pbe).project_requests.update_all(status: AbstractRequest::Status::NOT_ANSWERED)

    ids = (groups(:group_pbe_2).project_requests.active.collect(&:id) + groups(:group_pbe_1).project_requests.active.collect(&:id)).join(",")
    assert_permission_denied do
      post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::REJECTED, project_request_ids: ids, bulk_action: true,
        project_request: {
          response_text: "Rejecting all requests"
        }
      }
    end
    assert_equal [AbstractRequest::Status::NOT_ANSWERED], programs(:pbe).project_requests.collect(&:status).uniq
  end

  def test_project_requests_view_title
    @controller.expects(:current_program).at_least(0).returns(programs(:pbe))
    ProjectRequest.expects(:get_filtered_project_requests).with({page: 1}, {program: programs(:pbe)}).returns(ProjectRequest.where(id: [27, 28, 29, 30, 31]).paginate(page: 1, per_page: PER_PAGE))

    current_user_is :f_admin_pbe
    program = programs(:pbe)

    view = program.abstract_views.where(default_view: AbstractView::DefaultType::PENDING_PROJECT_REQUESTS).first
    section = program.report_sections.first
    metric = section.metrics.create(title: "Metric Title", description: "Pending project requests", abstract_view_id: view.id)

    get :index, params: { :metric_id => metric.id}
    assert_response :success

    assert_page_title("Metric Title")
  end

  def test_project_request_update_actions_withdraw_permission_denied
    project_request_id = ProjectRequest.find_by(status: AbstractRequest::Status::NOT_ANSWERED).id
    current_user_is :f_admin_pbe
    assert_permission_denied do
      post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::WITHDRAWN, project_request_ids: "#{project_request_id}" }
    end
  end

  def test_project_request_update_actions_withdraw
    sender_id = users(:pbe_student_2).id
    project_request = ProjectRequest.where(status: AbstractRequest::Status::NOT_ANSWERED, sender_id: sender_id).first
    response_text = "Withdrawal is my right"
    current_user_is :pbe_student_2
    post :update_actions, xhr: true, params: { request_type: AbstractRequest::Status::WITHDRAWN, project_request_ids: "#{project_request.id}", project_request: { response_text: response_text } }
    assert_response :success
    assert_equal project_request, assigns(:project_request)
    assert_equal AbstractRequest::Status::WITHDRAWN, project_request.reload.status
    assert_equal response_text, project_request.response_text
    assert_equal "The selected mentoring connection request has been withdrawn.", assigns(:flash_notice)
  end

  def test_project_request_manage_permission_denied
    current_user_is :pbe_student_2
    assert_permission_denied do
      get :manage
    end
  end

  def test_project_request_manage_instance_variables
    group = Group.first
    current_user_is :f_admin_pbe
    post :manage, xhr: true, params: { filters: { requestor: "abc"}, date_range: "09/06/2010 - 09/09/2018", filtered_group_ids: [group.id] }
    assert_response :success
    assert_equal Date.strptime("09/06/2010", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:start_time)
    assert_equal Date.strptime("09/09/2018", MeetingsHelper::DateRangeFormat.call).to_date, assigns(:end_time)
    assert_equal 1, assigns(:filters_count)
  end

  def test_project_request_manage_tile_data
    current_user_is :f_admin_pbe
    get :manage
    received_requests_scope = programs(:pbe).project_requests
    assert_equal ({
      received_count: received_requests_scope.size,
      pending_count: received_requests_scope.active.count,
      accepted_count: received_requests_scope.accepted.count,
      others_count: received_requests_scope.with_status_in([ProjectRequest::Status::REJECTED, ProjectRequest::Status::WITHDRAWN, ProjectRequest::Status::CLOSED]).count
    }), assigns(:project_request_hash)
  end
end