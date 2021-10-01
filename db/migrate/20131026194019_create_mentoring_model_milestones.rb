class CreateMentoringModelMilestones< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_milestones do |t|
      t.string :title
      t.text :description
      t.boolean :from_template, default: false
      t.belongs_to :group, :null => false
      t.timestamps null: false
    end
    add_index :mentoring_model_milestones, :group_id
  end
end
