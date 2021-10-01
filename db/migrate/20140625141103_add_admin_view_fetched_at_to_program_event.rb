class AddAdminViewFetchedAtToProgramEvent< ActiveRecord::Migration[4.2]
  def change
    add_column :program_events, :admin_view_fetched_at, :datetime
  end
end
