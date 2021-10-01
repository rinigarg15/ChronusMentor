class FixUserStateChangeMigrations< ActiveRecord::Migration[4.2]
  def up
    drop_table :user_state_changes
    
    create_table :user_state_changes do |t|
      t.belongs_to :user
      t.text :info
      t.integer :date_id

      t.timestamps null: false
    end
    add_index :user_state_changes, :user_id
    add_index :user_state_changes, :date_id

    # populate default state
    user_state_change_objects = []
    counter = 0
    one_day_to_i = 1.day.to_i
    User.select([:id, :state, :created_at]).includes([:role_references, :roles]).find_each do |user|
      info = {state: {}, role: {}}
      info[:state][:from] = info[:role][:from] = nil
      info[:state][:to] = user.state
      info[:role][:to] = user.role_ids
      transition = user.state_transitions.new(date_id: (user.created_at.utc.to_i/one_day_to_i))
      transition.set_info(info)
      user_state_change_objects << transition
      print '.' if counter % 100 == 0
      counter += 1
    end
    puts "\nDumping #{user_state_change_objects.size} objects into db"
    UserStateChange.import user_state_change_objects
  end

  def down
  end
end
