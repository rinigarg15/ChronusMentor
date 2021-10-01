class DigestV2RelatedFollowupMigrations< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Connection::Membership.table_name do |t|
        t.remove_column :notification_setting
        t.remove_column :last_update_sent_time
      end

      Lhm.change_table User.table_name do |t|
        t.remove_column :notification_setting
        t.remove_column :last_weekly_update_sent_time
        t.remove_column :allow_weekly_updates
      end
    end

    ChronusMigrate.data_migration do
      Mailer::Template.where(uid: 'nkscehaf').destroy_all # aggregated_mail.rb
      Mailer::Template.where(uid: 'ql9gxlz3').destroy_all # mentoring_area_digest.rb
      Mailer::Template.where(uid: 'ca95bx5m').destroy_all # weekly_updates.rb
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Connection::Membership.table_name do |t|
        t.add_column :last_update_sent_time, "datetime"
        t.add_column :notification_setting, "int(11) DEFAULT 0"
      end

      Lhm.change_table User.table_name do |t|
        t.add_column :last_weekly_update_sent_time, "datetime"
        t.add_column :notification_setting, "int(11)"
        t.add_column :allow_weekly_updates, "tinyint(1) DEFAULT 1"
      end
    end
  end
end
