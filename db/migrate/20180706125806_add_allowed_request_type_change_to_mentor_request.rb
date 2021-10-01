class AddAllowedRequestTypeChangeToMentorRequest < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table AbstractRequest.table_name do |t|
        t.add_column :allowed_request_type_change, "int(11) DEFAULT NULL"
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table AbstractRequest.table_name do |t|
        t.remove_column :allowed_request_type_change
      end
    end
  end
end