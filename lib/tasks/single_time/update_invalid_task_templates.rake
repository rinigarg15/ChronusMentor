namespace :single_time do
  desc 'Updating invalid task templates'
  task update_invalid_task_templates: :environment do
    milestone = MentoringModel::MilestoneTemplate.find(ENV['MILESTONE_TEMPLATE_ID'])
    unless milestone.mentoring_model_task_templates.pluck(:required).any?
      milestone.mentoring_model_task_templates.update_all(associated_id: nil)
    end
  end
end