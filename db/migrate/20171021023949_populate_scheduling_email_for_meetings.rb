class PopulateSchedulingEmailForMeetings< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Meeting.update_all(scheduling_email: APP_CONFIG[:scheduling_assistant_email].first)
    end
  end

  def down
    #Do nothing
  end
end
