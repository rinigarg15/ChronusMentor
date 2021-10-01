class AddIndexesToGroupIdScraps< ActiveRecord::Migration[4.2]
  def change
    add_index :scraps, :group_id
  end
end
