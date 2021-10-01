class DropSituationalMentoringRelatedTables< ActiveRecord::Migration[4.2]
  def up
    MatchConfig.where(:is_profile_field => false).delete_all
    remove_column :mentor_requests, :situation_id
    remove_column :match_configs, :is_profile_field
    drop_table :situations
    drop_table :mentoring_topics
    drop_table :mentoring_topic_users
    GroupViewColumn.where("column_key = 'situations'").destroy_all
  end

  def down
    add_column :mentor_requests, :situation_id, :integer
    add_column :match_configs, :is_profile_field, :boolean, :default => true

    create_table :situations do |t|
      t.string :title, :null => false
      t.text :description
      t.date :due_date
      t.belongs_to :mentoring_topic, :null => false
      t.belongs_to :user, :null => false
      t.timestamps null: false
    end
    add_index :situations, :user_id   
    add_index :situations, :mentoring_topic_id   

    create_table :mentoring_topics do |t|
      t.string :title, :null => false
      t.text :description
      t.belongs_to :program, :null => false
      t.timestamps null: false
    end
    add_index :mentoring_topics, :program_id

    create_table :mentoring_topic_users do |t|
      t.belongs_to :user, :null => false      
      t.belongs_to :mentoring_topic, :null => false
      t.timestamps null: false
    end
    add_index :mentoring_topic_users, [:user_id, :mentoring_topic_id]    
  end
end
