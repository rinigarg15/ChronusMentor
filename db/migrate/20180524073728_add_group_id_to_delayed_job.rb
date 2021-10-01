class AddGroupIdToDelayedJob < ActiveRecord::Migration[5.1]
  def up
  	# Here Job Group Id is an attribute of a group of DJs
    ChronusMigrate.ddl_migration do
      Lhm.change_table :delayed_jobs do |r|
        r.add_column :job_group_id, "varchar(20)"
        r.add_index :job_group_id
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :delayed_jobs do |r|
        r.remove_index :job_group_id
        r.remove_column :job_group_id
      end
    end
  end
end
