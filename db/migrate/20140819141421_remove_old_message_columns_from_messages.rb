class RemoveOldMessageColumnsFromMessages< ActiveRecord::Migration[4.2]
  def up
    remove_column :messages, :old_message_id
    remove_column :messages, :old_scrap_id
  end

  def down
  end
end
