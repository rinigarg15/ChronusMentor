class DigestV2RelatedMigrations< ActiveRecord::Migration[4.2]
  def add_new_columns_and_tables
    ChronusMigrate.ddl_migration do
      Lhm.change_table User.table_name do |t|
        t.add_column :group_notification_setting, "int(11) DEFAULT #{UserConstants::DigestV2Setting::GroupUpdates::WEEKLY}"
        t.add_column :last_group_update_sent_time, "datetime DEFAULT '2000-01-01 00:00:00'"
        t.add_column :program_notification_setting, "int(11) DEFAULT #{UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY}"
        t.add_column :last_program_update_sent_time, "datetime DEFAULT '2000-01-01 00:00:00'"
        t.change_column :notification_setting, "int(11) DEFAULT 0"
      end

      create_table :profile_views do |t|
        t.references :user, index: true
        t.references :viewed_by, index: true
        t.timestamps null: false
      end
    end
  end

  def get_new_group_notification_setting(settings)
    return UserConstants::DigestV2Setting::GroupUpdates::DAILY if settings.include?(1) # 1 => MentoringAreaConstants::NotifySetting::DAILY_DIGEST
    UserConstants::DigestV2Setting::GroupUpdates::WEEKLY
  end

  def get_new_program_notification_setting(setting)
    return UserConstants::DigestV2Setting::ProgramUpdates::IMMEDIATE if setting == 0 # => UserConstants::NotifySetting::ALL
    return UserConstants::DigestV2Setting::ProgramUpdates::DAILY if setting == 1 # => UserConstants::NotifySetting::DAILY_DIGEST
    UserConstants::DigestV2Setting::ProgramUpdates::WEEKLY
  end

  def do_data_migrations
    ChronusMigrate.data_migration(has_downtime: false) do
      User.reset_column_information
      counter = 0
      User.includes(:connection_memberships).find_each do |user|
        user.update_columns({
          group_notification_setting: get_new_group_notification_setting(user.connection_memberships.map(&:notification_setting)),
          last_group_update_sent_time: (user.connection_memberships.map(&:last_update_sent_time).compact.max || Time.now),
          program_notification_setting: get_new_program_notification_setting(user.notification_setting),
          last_program_update_sent_time: (user.last_weekly_update_sent_time || Time.now)
        })
        counter += 1
        puts counter if counter % 100 == 0
      end
    end
  end

  def up
    add_new_columns_and_tables
    do_data_migrations
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :profile_views

      Lhm.change_table User.table_name do |t|
        t.remove_column :last_program_update_sent_time
        t.remove_column :program_notification_setting
        t.remove_column :last_group_update_sent_time
        t.remove_column :group_notification_setting
      end
    end
  end
end
