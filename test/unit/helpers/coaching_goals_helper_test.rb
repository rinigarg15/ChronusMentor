require_relative './../../test_helper.rb'

class CoachingGoalsHelperTest < ActionView::TestCase
  def test_coaching_goal_status_icon
    coaching_goal = create_coaching_goal
    CoachingGoal.any_instance.stubs(:updating_user).returns(users(:f_mentor))
    set_response_text(render_coaching_goal_status_icon(coaching_goal))

    assert_select "h3" do
      assert_select "img", :src => "v4/progress.gif"
    end

    coaching_goal.update_attributes!(:due_date => (Time.now.utc - 10.days).to_date)
    assert_select "h3" do
      assert_select "img", :src => "v4/overdue.gif"
    end

    coaching_goal.update_attributes!(:due_date => (Time.now.utc + 10.days).to_date)
    assert_select "h3" do
      assert_select "img", :src => "v4/progress.gif"
    end

    coaching_goal.update_attributes!(:due_date => (Time.now.utc + 10.days).to_date)
    create_coaching_goal_activity(coaching_goal, :progress_value => 100, :initiator => users(:f_mentor))
    assert_select "h3" do
      assert_select "img", :src => "v4/progress.gif"
    end
  end
end
