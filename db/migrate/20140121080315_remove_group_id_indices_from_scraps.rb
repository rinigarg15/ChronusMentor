class RemoveGroupIdIndicesFromScraps< ActiveRecord::Migration[4.2]
  def up
    remove_index :scraps, :group_id
  end

  def down
    add_index :scraps, :group_id
  end
end
