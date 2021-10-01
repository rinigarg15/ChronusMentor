class RemoveProgramGoals< ActiveRecord::Migration[4.2]
  def up
    Feature.where(:name => "program_goals").each do |feature|
      feature.destroy
    end
    drop_table :program_goal_templates
    drop_table :program_goal_template_translations
    remove_index :mentoring_model_goal_templates, :program_goal_template_id
    remove_column :mentoring_model_goal_templates, :program_goal_template_id
  end

  def down
    Feature.create!(:name => "program_goals")
    create_table :program_goal_templates do |t|
      t.string  :title
      t.text    :description
      t.integer :program_id
      t.timestamps null: false
    end
    add_column :mentoring_model_goal_templates, :program_goal_template_id, :integer
    add_index :mentoring_model_goal_templates, :program_goal_template_id
  end
end
