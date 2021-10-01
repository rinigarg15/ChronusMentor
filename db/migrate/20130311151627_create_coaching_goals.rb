class CreateCoachingGoals< ActiveRecord::Migration[4.2]
  def change
    create_table :coaching_goals do |t|
      t.string :title
      t.text :description
      t.date :due_date
      t.belongs_to :group, :null => false
      t.integer :connection_membership_id
      t.integer :creator_id, :null => false
      t.timestamps null: false
    end

    add_index :coaching_goals, :group_id
  end
end
