class CreateProgramGoalsFeatureAndTable< ActiveRecord::Migration[4.2]
  def change
    if Feature.count > 0
      Feature.create_default_features
    end
    create_table :program_goal_templates do |t|
      t.string :title
      t.text :description
      t.integer :program_id
      t.timestamps null: false
    end
    add_index :program_goal_templates, :program_id
  end
end
