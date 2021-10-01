class MentoringModelTaskTemplatePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return if @options[:common]["flash_type"]
    mentoring_model_ids = @program.mentoring_models.pluck(:id)
    mentoring_models_task_template_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, mentoring_model_ids)
    process_patch(mentoring_model_ids, mentoring_models_task_template_hsh) 
  end

  def add_mentoring_model_task_templates(mentoring_model_ids, task_templates_count, options)
    performance_populator = PerformancePopulator.new
    mentoring_models = MentoringModel.where(id: mentoring_model_ids)
    self.class.benchmark_wrapper "Task Templates" do
      mentoring_models.each do |mentoring_model|
        admin_role_id = mentoring_model.program.roles.with_name([RoleConstants::ADMIN_NAME])
        user_role_ids = mentoring_model.program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
        mentoring_model.send("allow_manage_mm_tasks!", admin_role_id)
        mentoring_model.send("allow_manage_mm_tasks!", user_role_ids)
        milestone_template_ids = mentoring_model.mentoring_model_milestone_templates.pluck(:id)
        program = mentoring_model.program
        performance_populator.build_task_templates_model(program, mentoring_model, task_templates_count, {milestone_template_ids: milestone_template_ids, translation_locales: @translation_locales})
        self.dot
      end
      self.class.display_populated_count(mentoring_model_ids.size * task_templates_count, "Mentoring Model Task Template")
    end
  end

  def remove_mentoring_model_task_templates(mentoring_model_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentoring Model Task Template................" do
      program = options[:program]
      mentoring_model_task_template_ids = MentoringModel::TaskTemplate.where(:mentoring_model_id => mentoring_model_ids).select([:id, :mentoring_model_id]).group_by(&:mentoring_model_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      MentoringModel::TaskTemplate.where(:id => mentoring_model_task_template_ids).destroy_all
      self.class.display_deleted_count(mentoring_model_ids.size * count, "Mentoring Model Task Template")
    end
  end
end