class AddEnhancedMeetingSchedulerFeature < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Feature.count > 0
        Feature.create_default_features
      end
    end
  end

  def down
    # do nothing
  end
end
