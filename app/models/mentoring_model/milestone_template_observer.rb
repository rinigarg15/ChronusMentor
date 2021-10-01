class MentoringModel::MilestoneTemplateObserver < ActiveRecord::Observer
  def after_save(milestone_template)
    milestone_template.mentoring_model.increment_version_and_trigger_sync unless milestone_template. skip_increment_version_and_sync_trigger
  end

  def after_destroy(milestone_template)
    milestone_template.mentoring_model.increment_version_and_trigger_sync
  end
end