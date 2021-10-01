class AddMentoringModelMilestoneTemplateIdToMentoringModelMilestones< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_milestones, :mentoring_model_milestone_template_id, :integer
    add_index :mentoring_model_milestones, :mentoring_model_milestone_template_id, name: "index_mentoring_model_milestones_on_milestone_template_id"
  end
end
