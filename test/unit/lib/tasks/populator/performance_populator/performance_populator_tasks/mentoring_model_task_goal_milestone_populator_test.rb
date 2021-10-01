require_relative './../../../../../../test_helper'

class MentoringModelTaskGoalMilestonePopulatorTest < ActiveSupport::TestCase
  def test_add_mentoring_model_task
    org = programs(:org_primary)
    mentoring_model_task_template_populator = MentoringModelTaskTemplatePopulator.new("mentoring_model_task_template", {parent: "mentoring_model", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    mentoring_model_goal_template_populator = MentoringModelGoalTemplatePopulator.new("mentoring_model_goal_template", {parent: "mentoring_model", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    mentoring_model_milestone_template_populator = MentoringModelMilestoneTemplatePopulator.new("mentoring_model_milestone_template", {parent: "mentoring_model", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    mentoring_model = MentoringModel.find_by(title: "Project Based Engagement Template")
    mentoring_model_ids = mentoring_model.id

    assert_difference "mentoring_model.mentoring_model_task_templates.count", count do
      mentoring_model_task_template_populator.add_mentoring_model_task_templates(mentoring_model_ids, count, {organization: org})
    end

    assert_difference ["MentoringModel::GoalTemplate.count", "MentoringModel::Goal.count"], count do
      mentoring_model_goal_template_populator.add_mentoring_model_goal_templates(mentoring_model_ids, count, {organization: org})
    end

    assert_difference "MentoringModel::MilestoneTemplate.count", count do
      mentoring_model_milestone_template_populator.add_mentoring_model_milestone_templates(mentoring_model_ids, count, {organization: org})
    end

    group = Group.where(mentoring_model_id: mentoring_model.id).active.first
    assert_equal mentoring_model.reload.mentoring_model_task_templates.count, group.mentoring_model_tasks.size
    assert_equal mentoring_model.mentoring_model_goal_templates.count, group.mentoring_model_goals.size
    assert_equal mentoring_model.mentoring_model_milestone_templates.count, group.mentoring_model_milestones.size
    populator_object_save!(MentoringModel::Task.last)
  end

  def test_remove_mentoring_model_task
    org = programs(:org_primary)
    mentoring_model_task_template_populator = MentoringModelTaskTemplatePopulator.new("mentoring_model_task_template", {parent: "group", percents_ary: [50, 25, 25], counts_ary: [3, 2, 1]})
    count = 1
    mentoring_model_ids = MentoringModel.last.id
    mentoring_model_task_template_populator.add_mentoring_model_task_templates(mentoring_model_ids, count, {organization: org})
    assert_difference "MentoringModel::TaskTemplate.count", -count do
      mentoring_model_task_template_populator.remove_mentoring_model_task_templates(mentoring_model_ids, count, {organization: org})
    end
  end
end