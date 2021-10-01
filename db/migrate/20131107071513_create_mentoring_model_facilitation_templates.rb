class CreateMentoringModelFacilitationTemplates< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_facilitation_templates do |t|
      t.string :subject
      t.text :message
      t.integer :send_on
      t.belongs_to :program
      t.belongs_to :milestone_template

      t.timestamps null: false
    end
    add_index :mentoring_model_facilitation_templates, :program_id
    add_index :mentoring_model_facilitation_templates, :milestone_template_id, name: "index_facilitation_templates_on_milestone_template_id"
  end
end
