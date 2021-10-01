class CreateMentoringTopic< ActiveRecord::Migration[4.2]
  def up
  	create_table :mentoring_topics do |t|
      t.string :title, :null => false
      t.text :description
      t.belongs_to :program, :null => false
      t.timestamps null: false
    end
    add_index :mentoring_topics, :program_id
  end

  def down
    drop_table :mentoring_topics
  end
end
