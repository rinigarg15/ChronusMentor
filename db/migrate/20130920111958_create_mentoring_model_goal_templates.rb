class CreateMentoringModelGoalTemplates< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_goal_templates do |t|
      t.string :title
      t.text :description
      t.belongs_to :program
      t.timestamps null: false
    end
    add_index :mentoring_model_goal_templates, :program_id
  end
end
