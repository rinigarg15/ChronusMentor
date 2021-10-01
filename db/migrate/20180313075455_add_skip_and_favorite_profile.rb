class AddSkipAndFavoriteProfile < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Feature.create_default_features if Feature.count > 0
    end
  end
end
