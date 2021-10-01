class AddCleanupStatusToLocations< ActiveRecord::Migration[4.2]
  def change
    add_column :locations, :cleanup_status, :integer, default: Location::CleanupStatus::NOT_DONE
    add_index :locations, :city
    add_index :locations, :state
    add_index :locations, :country
    add_index :locations, [:city, :state, :country]
    add_index :locations, [:state, :country]
  end
end
