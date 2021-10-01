class AddActiveToMeetings< ActiveRecord::Migration[4.2]
  def change
    add_column :meetings, :active, :boolean, default: true
  end
end
