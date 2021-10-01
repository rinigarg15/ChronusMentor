class CreateMentoringModelTaskComment< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_task_comments do |t|
      t.belongs_to :program
      t.integer :sender_id
      t.text :content
      t.string :attachment_file_name
      t.string :attachment_content_type
      t.integer :attachment_file_size
      t.datetime :attachment_updated_at
      t.integer :mentoring_model_task_id
      t.timestamps null: false
    end
    add_index :mentoring_model_task_comments, :mentoring_model_task_id
    add_index :mentoring_model_task_comments, :program_id
    add_index :mentoring_model_task_comments, :sender_id
  end
end
