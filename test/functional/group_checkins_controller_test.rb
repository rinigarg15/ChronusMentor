require_relative './../test_helper.rb'

class GroupCheckinsControllerTest < ActionController::TestCase

  def setup
    super
    @group = groups(:mygroup)
    @program = programs(:albers)
    @milestone = create_mentoring_model_milestone
    @program.enable_feature(FeatureName::CONTRACT_MANAGEMENT)
  end

  def test_create_feature_disabled
    @program.enable_feature(FeatureName::CONTRACT_MANAGEMENT, false)
    task = create_mentoring_model_task

    current_user_is :f_mentor
    assert_raise Authorization::PermissionDenied do
      post :create, xhr: true, params: { task_id: task.id, group_id: @group.id, group_checkin: { comment: "This is test content", date: DateTime.new(2001, 1, 1), hours: 1, minutes: 15 }}
    end
  end

  def test_create_permission_denied_as_mentee_accesses
    task = create_mentoring_model_task(user: users(:mkr_student), milestone: @milestone)

    current_user_is task.user
    assert_raise Authorization::PermissionDenied do
      assert_no_difference "GroupCheckin.count" do
        post :create, xhr: true, params: { task_id: task.id, group_id: @group.id, group_checkin: { comment: "This is test content", date: DateTime.new(2001, 1, 1), hours: 1, minutes: 15 }}
      end
    end
  end

  def test_create_permission_denied_as_group_is_not_active
    mentor_user = @group.mentors.first
    task = create_mentoring_model_task(milestone: @milestone, user: mentor_user)
    @group.terminate!(users(:f_admin),"Test reason", @program.permitted_closure_reasons.first.id)

    current_user_is mentor_user
    assert_raise Authorization::PermissionDenied do
      post :create, xhr: true, params: { task_id: task.id, group_id: @group.id, group_checkin: { comment: "Test content", date: DateTime.new(2001, 1, 1), hours: 1, minutes: 15 }}
    end
  end

  def test_create
    task = create_mentoring_model_task(milestone: @milestone)

    current_user_is :f_mentor
    assert_difference 'GroupCheckin.count', 1 do
      post :create, xhr: true, params: { task_id: task.id, group_id: @group.id, group_checkin: { comment: "Test content", date: DateTime.new(2001, 1, 1), hours: 1, minutes: 15 }}
    end
    assert_response :success
    checkin = task.checkins.last
    assert_equal task.title, checkin.title
    assert_equal 75, checkin.duration
    assert_equal "Test content", checkin.comment
    assert_equal DateTime.new(2001, 1, 1), checkin.date
    assert_equal 1, checkin.hours
    assert_equal 15, checkin.minutes
    assert_equal task.id, checkin.checkin_ref_obj_id
    assert_equal task.class.name, checkin.checkin_ref_obj_type
  end

  def test_create_multiline_checkin
    task = create_mentoring_model_task(milestone: @milestone)

    current_user_is task.user
    assert_difference 'GroupCheckin.count', 1 do
      post :create, xhr: true, params: { task_id: task.id, group_id: @group.id, group_checkin: { comment: "Test \ncontent", date: DateTime.new(2001, 1, 1), hours: 1, minutes: 15 }}
    end
    assert_response :success
    assert_match /Test.*br.*content/, response.body
  end

  def test_show
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task)

    current_user_is task.user
    get :show, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id}
    assert_response :success
  end

  def test_update_permission_denied_as_different_mentor_accesses
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task, user: users(:f_mentor))

    current_user_is users(:f_mentor_student)
    assert_raise Authorization::PermissionDenied do
      patch :update, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id, group_checkin: { comment: "This is test content", date: DateTime.new(2001, 2, 2), hours: 1, minutes: 30 }}
    end
  end

  def test_update_permission_denied_as_group_is_not_active
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task)
    @group.terminate!(users(:f_admin),"Test reason", @program.permitted_closure_reasons.first.id)

    current_user_is task.user
    assert_permission_denied do
      patch :update, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id, group_checkin: { comment: "Updated Content", date: DateTime.new(2001,2,2), hours: 2, minutes: 30 }}
    end
  end

  def test_update
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task, comment: "New Comment")
    assert_equal "New Comment", checkin.comment

    current_user_is task.user
    patch :update, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id, group_checkin: { comment: "Updated Content", date: DateTime.new(2001,2,2), hours: 2, minutes: 30 }}
    assert_response :success
    checkin.reload
    assert_equal "Updated Content", checkin.comment
    assert_equal DateTime.new(2001, 2, 2), checkin.date
    assert_equal 2, checkin.hours
    assert_equal 30, checkin.minutes
  end

  def test_destroy_permission_denied_as_different_mentor_accesses
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task, user: users(:f_mentor))

    current_user_is users(:f_mentor_student)
    assert_permission_denied do
      assert_no_difference "GroupCheckin.count" do
        post :destroy, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id}
      end
    end
  end

  def test_destroy_permission_denied_as_group_is_not_active
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task)
    @group.terminate!(users(:f_admin),"Test reason", @program.permitted_closure_reasons.first.id)

    current_user_is task.user
    assert_permission_denied do
      assert_no_difference "GroupCheckin.count" do
        post :destroy, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id}
      end
    end
  end

  def test_destroy
    task = create_mentoring_model_task(milestone: @milestone)
    checkin = create_task_checkin(task)

    current_user_is task.user
    assert_difference 'GroupCheckin.count', -1 do
      post :destroy, xhr: true, params: { id: checkin.id, task_id: task.id, group_id: @group.id}
    end
  end

  def test_index_feature_disabled
    @program.enable_feature(FeatureName::CONTRACT_MANAGEMENT, false)

    current_user_is :f_admin
    assert_permission_denied { get :index }
  end

  def test_index_permission_denied
    current_user_is :f_mentor
    assert_permission_denied { get :index }
  end

  def test_index
    current_user_is :f_admin
    get :index
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_with_report
    current_user_is :f_admin
    get :index, params: { report: true, category: Report::Customization::Category::HEALTH}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
    assert_equal Report::Customization::Category::HEALTH, assigns(:category)
  end

  def test_index_sort_mentor_asc
    current_user_is :f_admin
    get :index, params: { sort: {"0"=>{"field"=>"mentor", "dir"=>"asc"}}}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_sort_mentor_desc
    current_user_is :f_admin
    get :index, params: { sort: {"0"=>{"field"=>"mentor", "dir"=>"desc"}}}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_sort_group_asc
    current_user_is :f_admin
    get :index, params: { sort: {"0"=>{"field"=>"group", "dir"=>"asc"}}}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_sort_group_desc
    current_user_is :f_admin
    get :index, params: { sort: {"0"=>{"field"=>"group", "dir"=>"desc"}}}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_mentor_filter_empty_results
    current_user_is :f_admin
    get :index, params: { filter: {"logic"=>"and", "filters"=>{"0"=>{"field"=>"mentor", "operator"=>"contains", "value"=>"Charles"}}}}
    assert_response :success
    assert_equal 0, assigns(:total_count)
    assert_equal [], assigns(:group_checkins)
  end

  def test_index_mentor_filter_non_empty_results
    current_user_is :f_admin
    get :index, params: { filter: {"logic"=>"and", "filters"=>{"0"=>{"field"=>"mentor", "operator"=>"contains", "value"=>"Good"}}}}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_group_filter_empty_results
    current_user_is :f_admin
    get :index, params: { filter: {"logic"=>"and", "filters"=>{"0"=>{"field"=>"group", "operator"=>"contains", "value"=>"Charles"}}}}
    assert_response :success
    assert_equal 0, assigns(:total_count)
    assert_equal [], assigns(:group_checkins)
  end

  def test_index_group_filter_non_empty_results
    current_user_is :f_admin
    get :index, params: { filter: {"logic"=>"and", "filters"=>{"0"=>{"field"=>"group", "operator"=>"contains", "value"=>"kumar"}}}}
    assert_response :success
    assert_equal 12, assigns(:total_count)
    assert_equal 1, assigns(:group_checkins).first.id
  end

  def test_index_date_filter
    time = Meeting.recurrent_meetings([Meeting.first]).last.first[:current_occurrence_time].to_date

    current_user_is :f_admin
    get :index, params: { filter: {"logic"=>"and", "filters"=>{"0"=>{"field"=>"date", "start_date"=>"#{time}", "end_date"=>"#{time}", "value"=>"between"}}} }
    assert_response :success
    assert_equal 2, assigns(:total_count)
  end

  def test_index_csv
    time = Meeting.recurrent_meetings([Meeting.first]).last.first[:current_occurrence_time].to_date

    current_user_is :f_admin
    get :index, params: { filter: {"logic"=>"and", "filters"=>{"0"=>{"field"=>"date", "start_date"=>"#{time}", "end_date"=>"#{time}", "value"=>"between"}}}, format: :csv}
    assert_equal "attachment; filename=Group_Stats.csv", @response.headers["Content-Disposition"]
  end
end