class RemoveMilestoneV1< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :allow_end_user_milestones
    remove_column :groups, :mentoring_template_id
    drop_table :connection_milestones
    drop_table :connection_tasks
    drop_table :mentoring_templates
    drop_table :mentoring_template_milestones
    drop_table :mentoring_template_tasks
    drop_table :mentoring_template_milestone_translations
    drop_table :mentoring_template_task_translations
    Feature.where(:name => "mentoring_milestones").each do |feature|
      feature.destroy
    end
  end

  def down
    add_column :programs, :allow_end_user_milestones, :boolean
    add_column :groups, :mentoring_template_id, :integer
    create_table :connection_milestones do |t|
      t.integer :id
      t.integer :template_milestone_id
      t.integer :group_id
      t.date :start_date
      t.date :start_date
      t.datetime :created_at
      t.datetime :updated_at
    end
    create_table :connection_tasks do |t|
      t.integer :id
      t.integer :template_task_id
      t.integer :milestone_id
      t.integer :owner_id
      t.integer :status
      t.date :due_date
      t.datetime :created_at
      t.datetime :updated_at
    end
    create_table :mentoring_templates do |t|
      t.integer :id
      t.integer :program_id
      t.string :title
      t.datetime :created_at
      t.datetime :updated_at
    end
    create_table :mentoring_template_milestones do |t|
      t.integer :id
      t.integer :mentoring_template_id
      t.string :title
      t.text :description
      t.integer :duration
      t.integer :position
      t.text :resources
      t.integer :connection_membership_id
      t.boolean :draft
      t.boolean :deleted
      t.boolean :publishing
      t.datetime :created_at
      t.datetime :updated_at
    end
    create_table :mentoring_template_tasks do |t|
      t.integer :id
      t.integer :milestone_id
      t.string :title
      t.integer :role_id
      t.integer :connection_membership_id
      t.text :description
      t.boolean :deleted
      t.integer :position
      t.datetime :created_at
      t.datetime :updated_at
    end
    add_index "connection_milestones", :template_milestone_id
    add_index "connection_milestones", ["group_id"], :name => "index_connection_milestones_on_group_id"
    add_index "connection_tasks", :owner_id
    add_index "connection_tasks", ["milestone_id"], :name => "index_connection_tasks_on_milestone_id"
    add_index "mentoring_templates", ["program_id"], :name => "index_mentoring_templates_on_program_id"
    add_index "mentoring_template_milestones", ["mentoring_template_id"], :name => "index_mentoring_template_milestones_on_mentoring_template_id"
    add_index "mentoring_template_tasks", ["milestone_id"], :name => "index_mentoring_template_tasks_on_milestone_id"
  end
end
