class RemoveInAppNotificationsFeature< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Feature.find_by(name: "inapp_notifications").try(:destroy)
    end
  end

  def down
    # do nothing
  end
end