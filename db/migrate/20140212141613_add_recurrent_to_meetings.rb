class AddRecurrentToMeetings< ActiveRecord::Migration[4.2]
  def change
  	add_column :meetings, :recurrent, :boolean, :default => false
  end
end
