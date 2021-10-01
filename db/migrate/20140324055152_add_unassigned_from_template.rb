class AddUnassignedFromTemplate< ActiveRecord::Migration[4.2]
  def change
    add_column :mentoring_model_tasks, :unassigned_from_template, :boolean, default: false
  end
end
