class ReIndexMessages< ActiveRecord::Migration[4.2]
  def up
    remove_index :messages, [:program_id, :type]
    remove_index :messages, [:sender_id]
    add_index :messages, [:program_id, :type, :created_at]
    add_index :messages, [:sender_id, :group_id]
  end

  def down
    remove_index :messages, [:program_id, :type, :created_at]
    remove_index :messages, [:sender_id, :group_id]
    add_index :messages, [:program_id, :type]
    add_index :messages, [:sender_id]
  end
end
