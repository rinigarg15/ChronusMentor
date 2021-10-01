namespace :single_time do

  #usage: bundle exec rake single_time:cleanup_task_templates_with_invalid_surveys
  desc "Cleanup task templates with invalid engagement surveys"
  task cleanup_task_templates_with_invalid_surveys: :environment do
    deleted_task_templates_ids = []
    Common::RakeModule::Utils.execute_task do
      Program.find_each do |program|
        survey_ids = program.surveys.of_engagement_type.pluck(:id)
        mentoring_model_ids = program.mentoring_models.pluck(:id)
        invalid_task_templates = MentoringModel::TaskTemplate.where(action_item_type: MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY, mentoring_model_id: mentoring_model_ids).where.not(action_item_id: survey_ids)
        invalid_task_template_ids = invalid_task_templates.collect(&:id)
        invalid_task_templates.each do |task_template|
          next if task_template.id.in?(deleted_task_templates_ids)
          cleanup_child_tasks(task_template, deleted_task_templates_ids, invalid_task_template_ids)
          task_template.destroy!
          deleted_task_templates_ids << task_template.id
        end
      end
    end
    puts "Deleted Task Template Ids: #{deleted_task_templates_ids}"
  end


  private

  def cleanup_child_tasks(task_template, deleted_task_templates_ids, invalid_task_template_ids)
    child_templates = task_template.task_templates
    child_templates.each do |child_template|
      if child_template.id.in?(invalid_task_template_ids)
        cleanup_child_tasks(child_template, deleted_task_templates_ids, invalid_task_template_ids)
        child_template.destroy!
        deleted_task_templates_ids << child_template.id
      end
    end
  end
end