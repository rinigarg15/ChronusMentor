class MentoringModelTaskPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    mentoring_model_ids = @program.mentoring_models.pluck(:id)
    add_mentoring_model_tasks(mentoring_model_ids)
  end

  def add_mentoring_model_tasks(mentoring_model_ids, task_templates_count = 0, options ={})
    self.class.benchmark_wrapper "Mentoring Model Task Goal Milestone Sync" do
      mentoring_models = @program.mentoring_models.includes(:groups).all
      mentoring_models.each do |mentoring_model|
        mentoring_model.groups.active.select([:id, :version]).each do |group|
          Group.sync_with_template(group.id, I18n.locale) if mentoring_model.version > group.version
        end
        self.dot
      end
    end
  end
end