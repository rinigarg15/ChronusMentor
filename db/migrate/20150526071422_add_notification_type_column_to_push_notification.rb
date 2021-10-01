class AddNotificationTypeColumnToPushNotification< ActiveRecord::Migration[4.2]
  def change
    add_column :push_notifications, :notification_type, :integer
  end
end
