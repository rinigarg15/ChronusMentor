class UpdateInvalidTasks< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      start_time = Time.now
      survey_tasks = MentoringModel::Task.joins("INNER JOIN surveys ON surveys.id = mentoring_model_tasks.action_item_id AND mentoring_model_tasks.action_item_type = #{MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY}").joins(:group).where("surveys.program_id != groups.program_id AND groups.status = #{Group::Status::CLOSED}")
      survey_tasks.includes(:mentoring_model_task_template).each do |survey_task|
        survey_task.update_column(:action_item_id, survey_task.mentoring_model_task_template.action_item_id)
      end
      puts "Time taken : #{Time.now - start_time} seconds"
    end
  end

  def down
    #Do nothing
  end
end