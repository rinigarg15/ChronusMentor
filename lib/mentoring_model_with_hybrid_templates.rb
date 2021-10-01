module MentoringModelWithHybridTemplates
  attr_accessor :skip_handle_hybrid_templates

  def mentoring_model_task_templates(*args)
    return super(*args) if self.skip_handle_hybrid_templates || self.base?

    sorted_template_ids = MentoringModel::TaskTemplate.compute_due_dates(base_templates.map { |bt| bt.mentoring_model_task_templates(*args) }.flatten, skip_positions: true).map(&:id)
    fetch_items_in_order(MentoringModel::TaskTemplate, sorted_template_ids)
  end

  def mentoring_model_goal_templates(*args)
    return super(*args) if self.skip_handle_hybrid_templates || self.base?

    ids = base_templates.map { |bt| bt.mentoring_model_goal_templates(*args).pluck(:id) }.flatten
    fetch_items_in_order(MentoringModel::GoalTemplate, ids)
  end

  def mentoring_model_milestone_templates(*args)
    return super(*args) if self.skip_handle_hybrid_templates || self.base?

    linked_milestone_templates = base_templates.map { |bt| bt.mentoring_model_milestone_templates(*args) }.flatten
    linked_milestone_templates.each(&:update_start_dates)
    cumulate_start_dates(linked_milestone_templates)
    linked_milestone_templates.sort_by! { |x| [x.start_date, x.id] }
    sorted_template_ids = linked_milestone_templates.map(&:id)
    fetch_items_in_order(MentoringModel::MilestoneTemplate, sorted_template_ids)
  end

  def mentoring_model_facilitation_templates(*args)
    return super(*args) if self.skip_handle_hybrid_templates || self.base?

    sorted_facilitation_template_ids = MentoringModel::FacilitationTemplate.compute_due_dates(base_templates.map { |bt| bt.mentoring_model_facilitation_templates(*args) }.flatten).sort_by(&:due_date).map(&:id)
    fetch_items_in_order(MentoringModel::FacilitationTemplate, sorted_facilitation_template_ids)
  end

  def mentoring_model_task_templates_without_handle_hybrid_templates(*args)
    self.skip_handle_hybrid_templates = true
    self.mentoring_model_task_templates(*args)
  end

  def mentoring_model_goal_templates_without_handle_hybrid_templates(*args)
    self.skip_handle_hybrid_templates = true
    self.mentoring_model_goal_templates(*args)
  end

  def mentoring_model_milestone_templates_without_handle_hybrid_templates(*args)
    self.skip_handle_hybrid_templates = true
    self.mentoring_model_milestone_templates(*args)
  end

  def mentoring_model_facilitation_templates_without_handle_hybrid_templates(*args)
    self.skip_handle_hybrid_templates = true
    self.mentoring_model_facilitation_templates(*args)
  end
end