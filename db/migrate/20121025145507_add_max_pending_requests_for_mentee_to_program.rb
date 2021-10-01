class AddMaxPendingRequestsForMenteeToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :max_pending_requests_for_mentee, :integer
  end
end
