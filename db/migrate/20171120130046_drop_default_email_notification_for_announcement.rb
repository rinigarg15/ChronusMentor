class DropDefaultEmailNotificationForAnnouncement< ActiveRecord::Migration[4.2]
  def up
		ChronusMigrate.ddl_migration do
			Lhm.change_table :announcements do |m|
				m.drop_column_default(:email_notification)
			end
		end
  end

  def down
		ChronusMigrate.ddl_migration do
			Lhm.change_table :announcements do |m|
				m.change_column_default(:email_notification, 0)
			end
		end
  end
end
