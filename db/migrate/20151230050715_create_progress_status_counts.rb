class CreateProgressStatusCounts< ActiveRecord::Migration[4.2]
  def change
    create_table :progress_status_counts do |t|
      t.belongs_to :progress_status
      t.integer :count
      t.timestamps null: false
    end
  end
end
