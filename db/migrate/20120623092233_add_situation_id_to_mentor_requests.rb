class AddSituationIdToMentorRequests< ActiveRecord::Migration[4.2]
  def change
  	add_column :mentor_requests, :situation_id, :integer
  	add_index :mentor_requests, :situation_id
  end
end
