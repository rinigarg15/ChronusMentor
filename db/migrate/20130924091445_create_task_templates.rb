class CreateTaskTemplates< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_task_templates do |t|
      t.belongs_to :program
      t.belongs_to :milestone_template
      t.belongs_to :goal_template
      t.boolean :required, default: false
      t.string :title
      t.text :description
      t.integer :duration
      t.belongs_to :associated
      t.integer :action_item_type
      t.integer :position
      t.belongs_to :role

      t.timestamps null: false
    end
    add_index :mentoring_model_task_templates, :program_id
    add_index :mentoring_model_task_templates, :milestone_template_id
    add_index :mentoring_model_task_templates, :goal_template_id
    add_index :mentoring_model_task_templates, :role_id
    add_index :mentoring_model_task_templates, :associated_id
  end
end
