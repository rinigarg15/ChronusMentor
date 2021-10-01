class AddMaxPickableSlotsToBulkMatch< ActiveRecord::Migration[4.2]
  def change
    add_column :bulk_matches, :max_pickable_slots, :integer
  end
end
