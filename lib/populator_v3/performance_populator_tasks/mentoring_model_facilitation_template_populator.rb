class MentoringModelFacilitationTemplatePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    mentoring_model_ids = @program.mentoring_models.pluck(:id)
    mentoring_models_facilitation_template_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, mentoring_model_ids)
    process_patch(mentoring_model_ids, mentoring_models_facilitation_template_hsh) 
  end

  def add_mentoring_model_facilitation_templates(mentoring_model_ids, facilitation_templates_count, options)
    performance_populator = PerformancePopulator.new
    self.class.benchmark_wrapper "Facilitation Templates" do
      mentoring_models = MentoringModel.where(id: mentoring_model_ids)
      mentoring_models.each do |mentoring_model|
        admin_role_id = mentoring_model.program.roles.with_name([RoleConstants::ADMIN_NAME])
        user_role_ids = mentoring_model.program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
        mentoring_model.send("allow_manage_mm_messages!", admin_role_id)
        mentoring_model.send("allow_manage_mm_messages!", user_role_ids)
        milestone_template_ids = mentoring_model.mentoring_model_milestone_templates.pluck(:id)
        program = mentoring_model.program
        performance_populator.build_facilitation_templates_model(program, mentoring_model, facilitation_templates_count, {milestone_template_ids: milestone_template_ids, translation_locales: @translation_locales})
        self.dot
      end
      self.class.display_populated_count(mentoring_model_ids.size * facilitation_templates_count, "Facilitation Templates")
    end
  end

  def remove_mentoring_model_facilitation_templates(mentoring_model_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentoring Model................" do
      program = options[:program]
      mentoring_model_facilitation_template_ids = MentoringModel::FacilitationTemplate.where(:mentoring_model_id => mentoring_model_ids).select([:id, :mentoring_model_id]).group_by(&:mentoring_model_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      MentoringModel::FacilitationTemplate.where(:id => mentoring_model_facilitation_template_ids).destroy_all
      self.class.display_deleted_count(mentoring_model_ids.size * count, "Facilitation Templates")
    end
  end
end