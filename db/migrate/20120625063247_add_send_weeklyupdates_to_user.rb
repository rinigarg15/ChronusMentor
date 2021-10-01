class AddSendWeeklyupdatesToUser< ActiveRecord::Migration[4.2]
  def change
    add_column :users, :allow_weekly_updates, :boolean, :default => true
  end
end
