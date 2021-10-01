require_relative './../../../test_helper.rb'

class MentoringModel::GoalsHelperTest < ActionView::TestCase
  def test_display_goal_status
    goal = create_mentoring_model_goal
    task = create_mentoring_model_task
    goal_tasks = goal.mentoring_model_tasks

    set_response_text(display_goal_status(goal.id, [], 0))
    assert_select "div.cjs-mentoring-model-goal-progress-#{goal.id}" do
      assert_select "div.text-muted", text: "(0 Tasks)"
    end

    set_response_text(display_goal_status(goal.id, [task], 90))
    assert_select "div.cjs-mentoring-model-goal-progress-#{goal.id}" do
      assert_select "div.font-bold", text: "90%"
    end

    set_response_text(display_goal_status(goal.id, [task], 0, {show_manage_connections_view: true, completed_tasks: goal_tasks.select{|task1| task1.done? }.size}))
    assert_select "div.cjs-mentoring-model-goal-progress-#{goal.id}" do
      assert_select "div.font-bold.pull-right", text: "0/1"
    end
  end
end