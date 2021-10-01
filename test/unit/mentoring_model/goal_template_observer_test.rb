require_relative './../../test_helper.rb'

class MentoringModel::GoalTemplateObserverTest < ActiveSupport::TestCase
  def test_increament_template_version_after_save
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    end
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      @goal_template.title = "Hello2"
      @goal_template.save!
    end
  end

  def test_increament_template_version_after_destroy
    program = programs(:albers)
    @mentoring_model = program.default_mentoring_model
    goal_template = @mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    template_version_increases_by_one_and_triggers_sync_once "@mentoring_model" do
      goal_template.destroy
    end
  end

  def test_before_destroy
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model

    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    
    assert_equal 3, goal_template.task_templates.size

    assert_difference "MentoringModel::TaskTemplate.count", -3 do
      goal_template.destroy
    end
  end

  def test_no_destroy_if_manual_progress
    program = programs(:albers)
    mentoring_model = program.default_mentoring_model
    mentoring_model.update_attribute(:goal_progress_type, MentoringModel::GoalProgressType::MANUAL)
    goal_template = mentoring_model.mentoring_model_goal_templates.create!(title: "Hello1", description: "Hello1Desc")
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    task_template1 = create_mentoring_model_task_template(goal_template_id: goal_template.id)
    
    assert_equal 3, goal_template.task_templates.size    
    assert_no_difference "MentoringModel::TaskTemplate.count" do
      goal_template.destroy
    end
    assert_equal [nil]*3, MentoringModel::TaskTemplate.last(3).collect(&:goal_template_id)
  end
end