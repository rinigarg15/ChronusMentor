class MentoringModel::TaskObserver < ActiveRecord::Observer
  def before_save(task)
    return if task.skip_observer
    task.due_date = nil unless task.required?
    update_task_positions(task) if task.new_record? || task.due_date_changed? || task.milestone_id_changed?
  end

  def after_update(task)
    return if task.skip_es_indexing
    MentoringModel::Task.es_reindex(task) if task.perform_delta
  end

  def after_create(task)
    return if task.skip_es_indexing
    MentoringModel::Task.es_reindex(task)
  end

  # deleting pending notifications which got created when task was created
  def after_destroy(task)
    pending_notifications = PendingNotification.where(:ref_obj_id => task, :ref_obj_type => "MentoringModel::Task", :program_id => task.group.program)
    pending_notifications.destroy_all
    MentoringModel::Task.es_reindex(task)
  end

  private

  def update_task_positions(task)
    unless task.skip_update_positions
      task.due_date_altered = true if !!task.updated_from_connection
      task.skip_update_positions = true
      object = MentoringModel::Task.scoping_object(task)
      MentoringModel::Task.update_positions(object.mentoring_model_tasks, task)
    end
  end

end