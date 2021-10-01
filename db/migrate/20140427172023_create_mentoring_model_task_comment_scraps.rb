class CreateMentoringModelTaskCommentScraps< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_task_comment_scraps do |t|
      t.integer :mentoring_model_task_comment_id
      t.integer :scrap_id

      t.timestamps null: false
    end
    add_index :mentoring_model_task_comment_scraps, :mentoring_model_task_comment_id, :name => "index_mentoring_model_task_comment_scrap_on_comment_id"
    add_index :mentoring_model_task_comment_scraps, :scrap_id
  end
end
