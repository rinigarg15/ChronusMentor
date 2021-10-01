class RemoveMilestonesV05< ActiveRecord::Migration[4.2]
  def up
    RecentActivity.where(:ref_obj_type => "Task").destroy_all
    drop_table :tasks
    Feature.where(:name => "mentoring_goals").each do |feature|
      feature.destroy
    end
    GroupViewColumn.where(:column_key => "Goal_Progress").destroy_all
  end

  def down
    create_table :tasks do |t|
      t.text :description
      t.date :due_date
      t.integer :group_id
      t.timestamps null: false
      t.string :title
      t.boolean :done
      t.integer :connection_membership_id
      t.integer :common_task_id
    end
    add_index "tasks", ["due_date"], :name => "index_tasks_on_due_date"
    add_index "tasks", ["updated_at"], :name => "index_tasks_on_updated_at"
    add_index :tasks, :group_id
  end
end
