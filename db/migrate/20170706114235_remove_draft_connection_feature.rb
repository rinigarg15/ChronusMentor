class RemoveDraftConnectionFeature< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration do
      feature = Feature.find_by(name: "draft_connections")
      feature.destroy if feature.present?
    end
  end

  def down
    ChronusMigrate.data_migration do
      Feature.create!(name: "draft_connections")
    end
  end
end
