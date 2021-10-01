class RemoveDualRequestModeFeature < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Feature.find_by(name: "dual_request_mode").try(:destroy)
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      Feature.create!(name: "dual_request_mode")
    end
  end
end
