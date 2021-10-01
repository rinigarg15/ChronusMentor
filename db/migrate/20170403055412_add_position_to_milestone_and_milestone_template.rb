class AddPositionToMilestoneAndMilestoneTemplate< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_milestones, :position, :integer
    add_column :mentoring_model_milestone_templates, :position, :integer
  end
end
