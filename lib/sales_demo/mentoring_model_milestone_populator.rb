module SalesDemo
  class MentoringModelMilestonePopulator < BasePopulator
    REQUIRED_FIELDS = MentoringModel::Milestone.attribute_names.map(&:to_sym) - [:id, :mentoring_model_milestone_template_id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :mentoring_model_milestones)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        mentoring_model_milestone = MentoringModel::Milestone.new.tap do |mentoring_model_milestone|
          assign_data(mentoring_model_milestone, ref_object)
          mentoring_model_milestone.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          mentoring_model_milestone.description = self.master_populator.handle_ck_editor_import(ref_object.description)
        end
        mentoring_model_milestone.template_version = 1 if mentoring_model_milestone.from_template?
        mentoring_model_milestone.save_without_timestamping!
        referer[ref_object.id] = mentoring_model_milestone.id
      end
      master_populator.referer_hash[:mentoring_model_milestone] = referer
    end
  end
end