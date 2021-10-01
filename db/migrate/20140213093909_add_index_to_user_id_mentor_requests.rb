class AddIndexToUserIdMentorRequests< ActiveRecord::Migration[4.2]
  def change
    add_index :mentor_requests, [:student_id, :type]
    add_index :mentor_requests, [:mentor_id, :type]
  end
end
