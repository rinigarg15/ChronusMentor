class AddClosureReasonIdToGroups< ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :closure_reason_id, :integer
  end
end