class AddEmailNotificationToProgramEvents< ActiveRecord::Migration[4.2]
  def change
    add_column :program_events, :email_notification, :boolean, :default => false
  end
end
