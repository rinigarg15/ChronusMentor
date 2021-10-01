class CreateMentoringTopicUser< ActiveRecord::Migration[4.2]
  def up
    create_table :mentoring_topic_users do |t|
      t.belongs_to :user, :null => false      
      t.belongs_to :mentoring_topic, :null => false
      t.timestamps null: false
    end
    add_index :mentoring_topic_users, [:user_id, :mentoring_topic_id]    
  end

  def down
    drop_table :mentoring_topic_users
  end
end
