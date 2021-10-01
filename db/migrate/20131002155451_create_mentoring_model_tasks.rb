class CreateMentoringModelTasks< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_tasks do |t|
      t.belongs_to :connection_membership
      t.belongs_to :group
      t.belongs_to :milestone
      t.belongs_to :goal
      t.boolean :required
      t.string :title
      t.text :description
      t.datetime :due_date
      t.integer :status
      t.integer :position
      t.integer :action_item_type
      t.boolean :from_template, default: false

      t.timestamps null: false
    end
    add_index :mentoring_model_tasks, :connection_membership_id
    add_index :mentoring_model_tasks, :group_id
    add_index :mentoring_model_tasks, :goal_id
    add_index :mentoring_model_tasks, :milestone_id
  end
end
