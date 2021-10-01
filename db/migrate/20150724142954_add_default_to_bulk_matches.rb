class AddDefaultToBulkMatches< ActiveRecord::Migration[4.2]
  def change
    add_column :bulk_matches, :default, :integer, :default => 1
  end
end
