class AddBulkMatchIdToGroups< ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :bulk_match_id, :integer
  end
end