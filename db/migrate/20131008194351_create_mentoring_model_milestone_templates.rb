class CreateMentoringModelMilestoneTemplates< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_milestone_templates do |t|
      t.string :title
      t.text :description
      t.belongs_to :program
      t.timestamps null: false
    end
    add_index :mentoring_model_milestone_templates, :program_id
  end
end
