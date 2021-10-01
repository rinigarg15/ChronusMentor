class RenameAdminMessageIdToMessageIdInEmailEventLog < ActiveRecord::Migration[4.2]

  def up
    rename_column :cm_email_event_logs, :admin_message_id, :message_id
  end

  def down
    rename_column :cm_email_event_logs, :message_id, :admin_message_id
  end
end
