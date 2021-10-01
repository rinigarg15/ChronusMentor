class AddIndexToGroupIdInMentorRequests< ActiveRecord::Migration[4.2]
  def change
    add_index :mentor_requests, :group_id
  end
end
