class AddClosedByAndClosedAtToMentorRequest< ActiveRecord::Migration[4.2]
  def change
    add_column :mentor_requests, :closed_by_id, :integer
    add_column :mentor_requests, :closed_at, :datetime
  end
end
