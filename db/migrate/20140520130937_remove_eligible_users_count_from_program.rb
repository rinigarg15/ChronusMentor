class RemoveEligibleUsersCountFromProgram< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :eligible_users_count
  end

  def down
    add_column :programs, :eligible_users_count, :integer
  end
end
