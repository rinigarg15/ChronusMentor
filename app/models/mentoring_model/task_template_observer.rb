class MentoringModel::TaskTemplateObserver < ActiveRecord::Observer
  def before_create(task_template)
    return if task_template.skip_observer
    if task_template.optional?
      update_task_template_duration(task_template)
      task_template.position = (task_template.mentoring_model.mentoring_model_task_templates.maximum(:position) || -1) + 1
      fill_associated_with_last_required_task(task_template) unless task_template.skip_associated_id_filling
    end
  end

  def before_update(task_template)
    link_children_to_parent(task_template) if task_template.changes[:required] == [true, false] || task_template_assigned_from_predecessor_to_specific_date(task_template)
    update_task_template_duration(task_template) if task_template.optional?
  end

  def after_save(task_template)
    return if task_template.skip_observer
    if !task_template.skip_due_date_computation && task_template.saved_changes.pick(:associated_id, :required, :duration, :position, :specific_date).present?
      task_template.update_task_template_positions
    end
    task_template.mentoring_model.increment_version_and_trigger_sync unless task_template.skip_increment_version_and_sync_trigger
  end

  def before_destroy(task_template)
    link_children_to_parent(task_template, reload_required: true)
  end

  def after_destroy(task_template)
    task_template.mentoring_model.increment_version_and_trigger_sync unless task_template.skip_increment_version_and_sync_trigger
  end

  private

  def task_template_assigned_from_predecessor_to_specific_date(task_template)
    task_template.changes[:duration] && task_template.changes[:specific_date] && task_template.changes[:duration][1] == 0 && task_template.changes[:specific_date][0] == nil
  end

  def select_task_templates(task_templates, milestone_template_id)
    task_templates.select do |task_template|
      task_template.milestone_template_id == milestone_template_id
    end
  end

  def fill_associated_with_last_required_task(task_template)
    task_template.associated_id = task_template.mentoring_model.mentoring_model_task_templates.required.last.try(:id)
  end

  def update_task_template_duration(task_template)
    task_template.duration = 0
  end

  def link_children_to_parent(task_template, options = {})
    options.reverse_merge!(carry_duration: true, reload_required: false)
    task_template.reload if options[:reload_required]
    children_task_templates = task_template.mentoring_model.mentoring_model_task_templates.where(associated_id: task_template.id)
    children_task_templates.each do |child|
      child.associated_id = task_template.associated_id
      child.duration += task_template.duration if options[:carry_duration]
      child.skip_due_date_computation = true
      child.skip_increment_version_and_sync_trigger = true
      child.save!
    end
  end
end