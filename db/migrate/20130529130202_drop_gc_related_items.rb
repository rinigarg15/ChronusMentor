class DropGcRelatedItems< ActiveRecord::Migration[4.2]
  def change
    remove_column :membership_requests, :gc_resolution
    remove_column :membership_requests, :resolver_id
    remove_column :membership_requests, :resolved_at
    drop_table :committee_responses
    drop_table :votes
  end
end