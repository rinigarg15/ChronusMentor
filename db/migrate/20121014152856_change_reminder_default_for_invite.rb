class ChangeReminderDefaultForInvite< ActiveRecord::Migration[4.2]
  def change
  	change_column :event_invites, :reminder, :boolean, :default => false
  end
end
