class RemoveUnusedColumns< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      # Drop Unused Columns
      Lhm.change_table CommonAnswer.table_name do |t|
        t.remove_column :membership_request_id
        t.remove_column :location_id
      end

      Lhm.change_table CommonQuestion.table_name do |t|
        t.remove_column :section_id
      end

      Lhm.change_table Education.table_name do |t|
        t.remove_index :user_answer_id
        t.remove_column :user_answer_id
      end

      Lhm.change_table Experience.table_name do |t|
        t.remove_index :user_answer_id
        t.remove_column :user_answer_id
      end

      Lhm.change_table MeetingProposedSlot.table_name do |t|
        t.remove_column :state
      end

      Lhm.change_table Meeting.table_name do |t|
        t.remove_column :parent_id
      end

      Lhm.change_table MembershipRequest.table_name do |t|
        t.remove_column :location_id
      end

      Lhm.change_table Ckeditor::Asset.table_name do |t|
        t.remove_index :user_id, :fk_user
        t.remove_column :user_id
      end

      Lhm.change_table AbstractNote.table_name do |t|
        t.remove_index :connection_membership_id
        t.remove_column :connection_membership_id
      end

      Lhm.change_table SolutionPack.table_name do |t|
        t.remove_column :user_id
      end

      # Drop Unused tables
      drop_table :common_tasks
      drop_table :messages_old
      drop_table :photos
      drop_table :profile_summary_fields
      drop_table :situation_groups
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table CommonAnswer.table_name do |t|
        t.add_column :membership_request_id, "int(11)"
        t.add_column :location_id, "int(11)"
      end

      Lhm.change_table CommonQuestion.table_name do |t|
        t.add_column :section_id, "int(11)"
      end

      Lhm.change_table Education.table_name do |t|
        t.add_column :user_answer_id, "int(11)"
        t.add_index :user_answer_id
      end

      Lhm.change_table Experience.table_name do |t|
        t.add_column :user_answer_id, "int(11)"
        t.add_index :user_answer_id
      end

      Lhm.change_table MeetingProposedSlot.table_name do |t|
        t.add_column :state, "int(11) DEFAULT '0'"
      end

      Lhm.change_table Meeting.table_name do |t|
        t.add_column :parent_id, "int(11)"
      end

      Lhm.change_table MembershipRequest.table_name do |t|
        t.add_column :location_id, "int(11)"
      end

      Lhm.change_table Ckeditor::Asset.table_name do |t|
        t.add_column :user_id, "int(11)"
        t.add_index :user_id, :fk_user
      end

      Lhm.change_table AbstractNote.table_name do |t|
        t.add_column :connection_membership_id, "int(11)"
        t.add_index :connection_membership_id
      end

      Lhm.change_table SolutionPack.table_name do |t|
        t.add_column :user_id, "int(11)"
      end

      create_table :common_tasks do |t|
        t.string :title
        t.integer :user_id
        t.integer :program_id
        t.integer :due_date_period
        t.boolean :include_all_connections, default: true
        t.boolean :include_future_connections, default: false
        t.integer :due_date
        t.timestamps null: false
      end

      create_table :photos do |t|
        t.integer :program_id
        t.string :picture_data_content_type
        t.string :picture_data_file_name
        t.integer :picture_data_file_size
        t.timestamps null: false
      end

      create_table :profile_summary_fields do |t|
        t.integer :common_question_id
        t.integer :default_question_id
        t.integer :program_id, null: false
        t.timestamps null: false
      end

      create_table :situation_groups do |t|
        t.integer :situation_id
        t.integer :group_id
      end
    end
  end

end
