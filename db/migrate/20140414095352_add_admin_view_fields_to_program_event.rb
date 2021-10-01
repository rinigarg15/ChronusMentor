class AddAdminViewFieldsToProgramEvent< ActiveRecord::Migration[4.2]
  def change
    add_column :program_events, :admin_view_id, :integer
    add_column :program_events, :admin_view_title, :string
  end
end
