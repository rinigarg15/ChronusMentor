class AddStatusToAnnouncements< ActiveRecord::Migration[4.2]
  def change
    add_column :announcements, :status, :integer, :default => 0
  end
end
