class CreateProgressStatuses< ActiveRecord::Migration[4.2]
  def change
    create_table :progress_statuses do |t|
      t.integer :ref_obj_id
      t.string :ref_obj_type
      t.string :for
      t.integer :completed_count
      t.integer :maximum
      t.timestamps null: false
    end
  end
end
