class AddTypeAndMaxSuggestionCountToBulkMatch< ActiveRecord::Migration[4.2]
  def change
    add_column :bulk_matches, :type, :string, default: BulkMatch.name
    add_column :bulk_matches, :max_suggestion_count, :integer
  end
end
