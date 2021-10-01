class AddAllowEndUsersToSeeMatchScoresToProgram< ActiveRecord::Migration[4.2]
  def change
  	add_column :programs, :allow_end_users_to_see_match_scores, :boolean, default: true
  end
end
