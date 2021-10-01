module SalesDemo
  class MentoringModelGoalPopulator < BasePopulator
    REQUIRED_FIELDS = MentoringModel::Goal.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :mentoring_model_goals)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        mentoring_model_goal = MentoringModel::Goal.new.tap do |mentoring_model_goal|
          assign_data(mentoring_model_goal, ref_object)
          mentoring_model_goal.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          mentoring_model_goal.mentoring_model_goal_template_id = master_populator.referer_hash[:mentoring_model_goal_template][ref_object.mentoring_model_goal_template_id]
          mentoring_model_goal.description = self.master_populator.handle_ck_editor_import(ref_object.description)
        end
        mentoring_model_goal.template_version = 1 if mentoring_model_goal.from_template?
        mentoring_model_goal.save_without_timestamping!
        referer[ref_object.id] = mentoring_model_goal.id
      end
      master_populator.referer_hash[:mentoring_model_goal] = referer
    end
  end
end