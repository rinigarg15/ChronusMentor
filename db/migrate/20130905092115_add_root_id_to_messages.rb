class AddRootIdToMessages< ActiveRecord::Migration[4.2]
  def up
    add_column :messages, :root_id, :integer, null: false, default: 0
  end

  def down
    remove_column :messages, :root_id
  end
end
