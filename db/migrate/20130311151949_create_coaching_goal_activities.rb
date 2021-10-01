class CreateCoachingGoalActivities< ActiveRecord::Migration[4.2]
  def change
    create_table :coaching_goal_activities do |t|
      t.belongs_to :coaching_goal, :null => false
      t.float :progress_value
      t.text :message
      t.integer :initiator_id, :null => false

      t.timestamps null: false
    end

    add_index :coaching_goal_activities, :coaching_goal_id
  end
end
