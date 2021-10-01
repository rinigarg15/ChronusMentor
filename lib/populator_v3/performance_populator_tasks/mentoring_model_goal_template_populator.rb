class MentoringModelGoalTemplatePopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    return if @options[:common]["flash_type"]
    mentoring_model_ids = @program.mentoring_models.pluck(:id)
    mentoring_model_goal_template_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, mentoring_model_ids)
    process_patch(mentoring_model_ids, mentoring_model_goal_template_hsh) 
  end

  def add_mentoring_model_goal_templates(mentoring_model_ids, goal_templates_count, options)
    performance_populator = PerformancePopulator.new
    mentoring_models = MentoringModel.where(id: mentoring_model_ids)
    self.class.benchmark_wrapper "Goal Templates" do
      mentoring_models.each do |mentoring_model|
        admin_role_id = mentoring_model.program.roles.with_name([RoleConstants::ADMIN_NAME])
        user_role_ids = mentoring_model.program.roles.with_name([RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME])
        mentoring_model.send("allow_manage_mm_goals!", admin_role_id)
        mentoring_model.send("allow_manage_mm_goals!", user_role_ids)
        performance_populator.build_goal_templates(mentoring_model, goal_templates_count, {translation_locales: @translation_locales})
        self.dot
      end
      self.class.display_populated_count(mentoring_model_ids.size * goal_templates_count, "Goal Templates")
    end
  end

  def remove_mentoring_model_goal_templates(mentoring_model_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Mentoring Model Goal Templates................" do
      program = options[:program]
      mentoring_model_goal_template_ids = MentoringModel::GoalTemplate.where(:mentoring_model_id => mentoring_model_ids).select([:id, :mentoring_model_id]).group_by(&:mentoring_model_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      MentoringModel::GoalTemplate.where(:id => mentoring_model_goal_template_ids).destroy_all
      self.class.display_deleted_count(mentoring_model_ids.size * count, "Goal Templates")
    end
  end
end