require_relative './../../../test_helper.rb'

class MentoringModel::ManualProgressGoalsHelperTest < ActionView::TestCase
  def test_manual_progress_goal_progress_bar
    goal_template = create_mentoring_model_goal_template
    
    goal = create_mentoring_model_goal
    goal.mentoring_model_goal_template_id = goal_template.id
    goal.save!
    self.stubs(:progress_bar).with(0, {:id => "progress_#{goal.id}", :tooltip => true, :tooltip_content => '0%', :class => 'progress-small no-margins'}).returns(1)
    content = manual_progress_goal_progress_bar(goal.group, goal)
    assert_equal 1, content
  end

  def test_display_update_link
    goal = create_mentoring_model_goal
    content = display_update_link(goal)
    set_response_text content

    assert_select "a.small.cjs_manual_progress_goal_update_link.strong[href=\"#{new_group_mentoring_model_goal_activity_path(goal.group, goal)}\"]", text: "Update"
  end

  def test_display_percentage
    assert_equal "abcdef%", display_percentage("abcdef")
  end

  def test_goal_activity_title_text
    goal = create_mentoring_model_goal
    goal_activity = create_mentoring_model_goal_activity(goal, {progress_value: 23})

    title_text1 = goal_activity_title_text(goal_activity, goal_activity.user)
    assert_match /You/, title_text1
    assert_match /23%/, title_text1

    title_text2 = goal_activity_title_text(goal_activity, users(:f_mentor))
    assert_match /#{link_to_user(goal_activity.user)}/, title_text2
    assert_match /23%/, title_text2

    goal_activity = create_mentoring_model_goal_activity(MentoringModel::Goal.first)
    
    title_text3 = goal_activity_title_text(goal_activity, goal_activity.user)
    assert_match /You/, title_text3
    assert_match /comment/, title_text3

    title_text4 = goal_activity_title_text(goal_activity, users(:f_mentor))
    assert_match /#{link_to_user(goal_activity.user)}/, title_text4
    assert_match /comment/, title_text4
  end
end
