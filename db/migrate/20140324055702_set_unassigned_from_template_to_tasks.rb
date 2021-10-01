class SetUnassignedFromTemplateToTasks< ActiveRecord::Migration[4.2]
  def up
    MentoringModel::Task.where(connection_membership_id: nil).where(from_template: true).update_all(unassigned_from_template: true)
  end

  def down
  end
end
