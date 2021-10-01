module SalesDemo
  class MentoringModelTemplatePopulator < BasePopulator
    ASSOCIATED_MODELS = {
      :mentoring_model_milestone_templates => "SalesDemo::MentoringModelMilestoneTemplatePopulator",
      :mentoring_model_goal_templates => "SalesDemo::MentoringModelGoalTemplatePopulator",
      :mentoring_model_task_templates => "SalesDemo::MentoringModelTaskTemplatePopulator",
    }

    def initialize(master_populator)
      self.master_populator = master_populator
    end

    def copy_data
      ASSOCIATED_MODELS.each do |key, value|
        value.constantize.new(master_populator).copy_data
      end
    end
  end
end