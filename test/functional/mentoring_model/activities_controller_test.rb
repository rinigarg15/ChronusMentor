require_relative './../../test_helper.rb'

class MentoringModel::ActivitiesControllerTest < ActionController::TestCase
  def test_new_without_permission
    current_user_is :f_student
    current_program_is :albers
    group = groups(:mygroup)
    assert_permission_denied do
      get :new, xhr: true, params: { group_id: group.id, goal_id: ""}
    end
  end

  def test_create_without_permission
    current_user_is :f_student
    current_program_is :albers
    group = groups(:mygroup)
    assert_permission_denied do
      post :create, xhr: true, params: { group_id: group.id, goal_id: ""}
    end
  end

  def test_new
    current_user_is :f_mentor
    current_program_is :albers
    group = groups(:mygroup)
    group.mentoring_model = group.program.mentoring_models.first 

    goal_template = create_mentoring_model_goal_template(mentoring_model_id: group.mentoring_model.id)
    goal = create_mentoring_model_goal(group_id: group.id)
    goal.mentoring_model_goal_template = goal_template
    goal.save!

    get :new, xhr: true, params: { group_id: group.id, goal_id: goal.id}
    assert_equal goal.id, assigns(:goal_activity).ref_obj.id
  end

  def test_create
    current_user_is :f_mentor
    current_program_is :albers
    group = groups(:mygroup)
    group.mentoring_model = group.program.mentoring_models.first 

    goal_template = create_mentoring_model_goal_template(mentoring_model_id: group.mentoring_model.id)
    goal = create_mentoring_model_goal(group_id: group.id)
    goal.mentoring_model_goal_template = goal_template
    goal.save!

    assert_difference 'RecentActivity.count', 1 do
      assert_difference 'MentoringModel::Activity.count', 1 do
        post :create, xhr: true, params: { group_id: group.id, goal_id: goal.id, progress_slider: "23", mentoring_model_activity: {message: "message"}}
        assert_response :success
      end
    end
    activity = MentoringModel::Activity.last
    assert_equal users(:f_mentor), activity.connection_membership.user
    assert_equal "message", activity.message
    assert_equal 23, activity.progress_value
  end

  def test_create_from_student
    current_user_is :f_student
    current_program_is :albers
    group = groups(:mygroup)
    group.mentoring_model = group.program.mentoring_models.first 

    goal_template = create_mentoring_model_goal_template(mentoring_model_id: group.mentoring_model.id)
    goal = create_mentoring_model_goal(group_id: group.id)
    goal.mentoring_model_goal_template = goal_template
    goal.save!

    assert_no_difference 'RecentActivity.count' do
      assert_no_difference 'MentoringModel::Activity.count' do
        assert_permission_denied do
          post :create, params: { group_id: group.id, goal_id: goal.id, progress_slider: "23", mentoring_model_activity: {message: "message"}}
        end
      end
    end
  end
end