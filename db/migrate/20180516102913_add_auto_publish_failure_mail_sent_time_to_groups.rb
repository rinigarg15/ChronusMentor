class AddAutoPublishFailureMailSentTimeToGroups < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table Group.table_name do |table|
        table.add_column :auto_publish_failure_mail_sent_time, "datetime"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table Group.table_name do |table|
        table.remove_column :auto_publish_failure_mail_sent_time
      end
    end
  end
end
