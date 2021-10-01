class AddStateMarkedAtToMeeting< ActiveRecord::Migration[4.2]
  def change
  	add_column :meetings, :state_marked_at, :datetime
  end
end
