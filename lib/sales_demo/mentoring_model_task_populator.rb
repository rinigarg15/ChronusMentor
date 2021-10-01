module SalesDemo
  class MentoringModelTaskPopulator < BasePopulator
    include PopulatorUtils
    REQUIRED_FIELDS = MentoringModel::Task.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :due_date]

    def initialize(master_populator)
      super(master_populator, :mentoring_model_tasks)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        mentoring_model_task = MentoringModel::Task.new.tap do |mentoring_model_task|
          assign_data(mentoring_model_task, ref_object)
          mentoring_model_task.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          mentoring_model_task.goal_id = master_populator.referer_hash[:mentoring_model_goal][ref_object.goal_id]
          mentoring_model_task.milestone_id = master_populator.referer_hash[:mentoring_model_milestone][ref_object.milestone_id]
          mentoring_model_task.connection_membership_id = master_populator.referer_hash[:connection_membership][ref_object.connection_membership_id]
          mentoring_model_task.mentoring_model_task_template_id = master_populator.referer_hash[:mentoring_model_task_template][ref_object.mentoring_model_task_template_id]
          mentoring_model_task.description = self.master_populator.handle_ck_editor_import(ref_object.description)
          mentoring_model_task.action_item_id = get_action_item_id(ref_object.action_item_type, ref_object.action_item_id)
        end
        mentoring_model_task.template_version = 1 if mentoring_model_task.from_template?
        mentoring_model_task.save_without_timestamping!
        referer[ref_object.id] = mentoring_model_task.id
      end
      master_populator.referer_hash[:mentoring_model_task] = referer
    end

    def get_action_item_id(action_item_type, action_item_id)
      if action_item_type == MentoringModel::TaskTemplate::ActionItem::ENGAGEMENT_SURVEY
        return self.master_populator.solution_pack_referer_hash["Survey"][action_item_id]
      else
        return action_item_id
      end
    end
  end
end