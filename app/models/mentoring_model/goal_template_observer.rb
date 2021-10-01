class MentoringModel::GoalTemplateObserver < ActiveRecord::Observer
  def after_save(goal_template)
    goal_template.mentoring_model.increment_version_and_trigger_sync unless goal_template.skip_increment_version_and_sync_trigger
  end

  def before_destroy(goal_template)
    goal_template.mentoring_model.manual_progress_goals? ? goal_template.task_templates.map{|task_temp| task_temp.update_attribute(:goal_template_id, nil)} : goal_template.task_templates.destroy_all
  end

  def after_destroy(goal_template)
    goal_template.mentoring_model.increment_version_and_trigger_sync
  end
end