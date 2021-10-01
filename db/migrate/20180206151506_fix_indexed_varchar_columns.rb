class FixIndexedVarcharColumns  < ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table UserActivity.table_name do |t|
        t.change_column :activity, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
      end

      Lhm.change_table Delayed::Job.table_name do |t|
        t.change_column :queue, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
      end

      Lhm.change_table QuestionChoice.table_name do |t|
        t.change_column :ref_obj_type, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
      end

      Lhm.change_table AnswerChoice.table_name do |t|
        t.change_column :ref_obj_type, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
      end

      Lhm.change_table ViewedObject.table_name do |t|
        t.change_column :ref_obj_type, "varchar(#{UTF8MB4_VARCHAR_LIMIT})"
      end
    end
  end

  def down
  end
end