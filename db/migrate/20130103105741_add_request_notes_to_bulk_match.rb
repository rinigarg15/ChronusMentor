class AddRequestNotesToBulkMatch< ActiveRecord::Migration[4.2]
  def change
  	add_column :bulk_matches, :request_notes, :boolean, :default => true
  end
end
