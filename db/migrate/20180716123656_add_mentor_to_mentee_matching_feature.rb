class AddMentorToMenteeMatchingFeature < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Feature.count > 0
        Feature.create_default_features
      end
    end
  end

  def down
  end
end
