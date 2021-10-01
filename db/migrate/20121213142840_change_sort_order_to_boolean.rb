class ChangeSortOrderToBoolean< ActiveRecord::Migration[4.2]
  def change
    change_column :bulk_matches, :sort_order, :boolean, :default => true
  end
end