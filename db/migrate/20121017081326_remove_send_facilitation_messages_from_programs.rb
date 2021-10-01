class RemoveSendFacilitationMessagesFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :send_facilitation_messages
  end

  def down
    add_column :programs, :send_facilitation_messages, :boolean
  end
end
