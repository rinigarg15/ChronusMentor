class AddEmailNotificationToAnnouncements< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Announcement.table_name do |table|
        table.add_column :email_notification, "int(11) DEFAULT #{UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE}"
      end
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      announcement_mailer_uids = [AnnouncementNotification, AnnouncementUpdateNotification].map { |mailer| mailer.mailer_attributes[:uid] }
      Mailer::Template.where(uid: announcement_mailer_uids).update_all(enabled: true)
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Announcement.table_name do |table|
        table.remove_column :email_notification
      end
    end
  end
end
