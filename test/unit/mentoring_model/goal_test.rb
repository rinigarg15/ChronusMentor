require_relative './../../test_helper.rb'

class MentoringModel::GoalTest < ActiveSupport::TestCase

  def test_validations
    group = groups(:mygroup)

    goal = MentoringModel::Goal.new
    assert_false goal.valid?
    assert_equal ["can't be blank"], goal.errors[:title]
    assert_equal ["can't be blank"], goal.errors[:group]
    assert_empty goal.errors[:template_version]

    goal.title = "Hello1"
    goal.description = "Hello1Desc"
    goal.group_id = group.id
    assert goal.valid?

    goal.from_template = true
    assert_false goal.valid?
    assert_equal ["is not a number"], goal.errors[:template_version]

    goal.template_version = -1
    assert_false goal.valid?
    assert_equal ["must be greater than 0"], goal.errors[:template_version]

    goal.template_version = 1
    assert goal.valid?
  end

  def test_translated_fields
    goal = create_mentoring_model_goal(from_template: true)
    Globalize.with_locale(:en) do
      goal.title = "english title"
      goal.description = "english description"
      goal.save!
    end
    Globalize.with_locale(:"fr-CA") do
      goal.title = "french title"
      goal.description = "french description"
      goal.save!
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", goal.title
      assert_equal "english description", goal.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", goal.title
      assert_equal "french description", goal.description
    end
  end

  def test_has_many_mentoring_model_tasks
    milestone1 = create_mentoring_model_milestone
    milestone2 = create_mentoring_model_milestone
    goal1 = create_mentoring_model_goal
    task1 = create_mentoring_model_task
    task2 = create_mentoring_model_task

    task1.update_attributes!(goal_id: goal1.id, required: true, due_date: Date.today)
    task2.update_attributes!(goal_id: goal1.id, required: true, due_date: Date.today + 2.days)

    assert_equal [task1, task2], goal1.reload.mentoring_model_tasks

    task1.update_attributes!(milestone_id: milestone2.id, due_date: Date.today + 2.days)
    task2.update_attributes!(milestone_id: milestone1.id, due_date: Date.today + 5.days)
    
    assert_equal [task2, task1], goal1.reload.mentoring_model_tasks

    assert_difference "MentoringModel::Task.count", -2 do
        goal1.destroy
    end
  end

def test_compute_goal_completion_percentage
    group = groups(:mygroup)
    goal_1 = create_mentoring_model_goal
    goal_2 = create_mentoring_model_goal
    goal_3 = create_mentoring_model_goal

    task_1 = create_mentoring_model_task(required: true, goal_id: goal_1.id, status: MentoringModel::Task::Status::DONE)
    task_2 = create_mentoring_model_task(required: true, goal_id: goal_2.id)
    task_3 = create_mentoring_model_task(required: true, goal_id: goal_3.id, status: MentoringModel::Task::Status::DONE)
    task_4 = create_mentoring_model_task(required: true, goal_id: goal_3.id)
    task_5 = create_mentoring_model_task(goal_id: goal_3.id)

    req_task1 = group.mentoring_model_tasks.required.where(goal_id: goal_1.id)
    req_task2 = group.mentoring_model_tasks.required.where(goal_id: goal_2.id)
    req_task3 = group.mentoring_model_tasks.required.where(goal_id: goal_3.id)

    assert_equal 100, goal_1.completion_percentage(req_task1)
    assert_equal 0, goal_2.completion_percentage(req_task2)
    assert_equal 50, goal_3.completion_percentage(req_task3)
  end

  def test_completion_percentage_for_manual_progress_goal_scenario
    goal_1 = create_mentoring_model_goal
    goal_1.expects(:manual_progress_goal?).at_least(1).returns(true)
    assert_equal 0, goal_1.completion_percentage
    create_mentoring_model_goal_activity(goal_1, {progress_value: 23})
    assert_equal 23, goal_1.reload.completion_percentage
    create_mentoring_model_goal_activity(goal_1, {progress_value: nil})
    assert_equal 23, goal_1.reload.completion_percentage
    create_mentoring_model_goal_activity(goal_1, {progress_value: 48})
    assert_equal 48, goal_1.reload.completion_percentage
  end

  def test_manual_progress_goal
    group = groups(:mygroup)
    goal = create_mentoring_model_goal
    assert_false goal.manual_progress_goal?

    default_mentoring_model = goal.group.program.default_mentoring_model
    default_mentoring_model.goal_progress_type = MentoringModel::GoalProgressType::MANUAL
    default_mentoring_model.save!
    assert goal.reload.manual_progress_goal?

    mentoring_model = group.program.mentoring_models.last
    mentoring_model.goal_progress_type = MentoringModel::GoalProgressType::AUTO
    mentoring_model.save!
    group.mentoring_model = mentoring_model
    group.save!
    assert goal.manual_progress_goal?

    mentoring_model.goal_progress_type = MentoringModel::GoalProgressType::MANUAL
    mentoring_model.save!
    assert goal.reload.manual_progress_goal?
  end

  def test_from_template
    group = groups(:mygroup)
    goal_1 = create_mentoring_model_goal(from_template: false)
    goal_2 = create_mentoring_model_goal(from_template: true)
    assert_equal [goal_2], group.mentoring_model_goals.reload.from_template
  end

  def test_translatable_fields_for_not_from_template_goals
    group = groups(:mygroup)
    goal_1 = create_mentoring_model_goal(from_template: false)
    Globalize.with_locale(:en) do
      goal_1.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"fr-CA") do
      goal_1.update_attributes(title: "french title", description: "french description")
    end
    assert_equal 1, goal_1.translations.count
    Globalize.with_locale(:en) do
      assert_equal "french title", goal_1.title
      assert_equal "french description", goal_1.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", goal_1.title
      assert_equal "french description", goal_1.description
    end

    goal_2 = create_mentoring_model_goal(from_template: true)
    Globalize.with_locale(:en) do
      goal_2.update_attributes(title: "english title", description: "english description")
    end
    Globalize.with_locale(:"fr-CA") do
      goal_2.update_attributes(title: "french title", description: "french description")
    end
    Globalize.with_locale(:en) do
      assert_equal "english title", goal_2.title
      assert_equal "english description", goal_2.description
    end
    Globalize.with_locale(:"fr-CA") do
      assert_equal "french title", goal_2.title
      assert_equal "french description", goal_2.description
    end
  end

  def test_activity_dependent_destroy
    group = groups(:mygroup)
    goal = create_mentoring_model_goal(from_template: false)
    goal_activity = goal.goal_activities.new(:message => "Message", :connection_membership => group.memberships.first)
    goal_activity.member_id = group.memberships.first.user.member_id
    goal_activity.save!
    assert_difference 'MentoringModel::Activity.count', -1 do
      goal.destroy
    end
  end

  def test_associtation_latest_activity
    goal_1 = create_mentoring_model_goal
    assert_nil goal_1.latest_activity
    act1 = create_mentoring_model_goal_activity(goal_1, {progress_value: 23})
    assert_equal act1, goal_1.reload.latest_activity
    act2 = create_mentoring_model_goal_activity(goal_1, {progress_value: nil})
    assert_equal act1, goal_1.reload.latest_activity
    assert_not_equal act2, goal_1.reload.latest_activity
    act3 = create_mentoring_model_goal_activity(goal_1, {progress_value: 48})
    assert_equal act3, goal_1.reload.latest_activity
  end

  def test_get_time_taken_to_reach_lastest_progress_in_days
    goal_1 = create_mentoring_model_goal
    group = goal_1.group
    assert_equal goal_1.get_time_taken_to_reach_lastest_progress_in_days, 0
    
    act1 = create_mentoring_model_goal_activity(goal_1, {progress_value: 23})
    act1.update_attribute(:created_at, (group.published_at + 10.hours))
    assert_equal goal_1.reload.get_time_taken_to_reach_lastest_progress_in_days, 1
    
    act2 = create_mentoring_model_goal_activity(goal_1, {progress_value: nil})
    act2.update_attribute(:created_at, (group.published_at + 5.days))
    assert_equal goal_1.reload.get_time_taken_to_reach_lastest_progress_in_days, 1

    act1.update_attribute(:created_at, (group.published_at + 10.days))
    assert_equal goal_1.reload.get_time_taken_to_reach_lastest_progress_in_days, 11
  end
end