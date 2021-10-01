class RemoveIndexToUserIdMentorRequests< ActiveRecord::Migration[4.2]
  def change
    remove_index :mentor_requests, [:student_id, :type]
    remove_index :mentor_requests, [:mentor_id, :type]
  end
end