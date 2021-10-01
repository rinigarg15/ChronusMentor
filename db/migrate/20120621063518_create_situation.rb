class CreateSituation< ActiveRecord::Migration[4.2]
  def up
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
  end

  def down
    drop_table :situations
  end
end
