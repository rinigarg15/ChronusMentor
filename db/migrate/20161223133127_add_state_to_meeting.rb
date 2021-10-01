class AddStateToMeeting< ActiveRecord::Migration[4.2]
  def change
    add_column :meetings, :state, :string
  end
end
