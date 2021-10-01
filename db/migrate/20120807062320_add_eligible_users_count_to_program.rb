class AddEligibleUsersCountToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :eligible_users_count, :integer
  end
end
