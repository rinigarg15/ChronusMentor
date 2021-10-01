class AddAllowMenteeWithdrawMentorRequestToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_mentee_withdraw_mentor_request, :boolean, :default => false
  end
end
