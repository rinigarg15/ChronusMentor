class CreateMentoringModelActivities< ActiveRecord::Migration[4.2]
  def change
    create_table :mentoring_model_activities do |t|
      t.references :ref_obj, polymorphic: { limit: UTF8MB4_VARCHAR_LIMIT }
      t.float :progress_value
      t.text :message
      t.references :connection_membership

      t.timestamps null: false
    end
    add_index :mentoring_model_activities, [:ref_obj_id, :ref_obj_type]
  end
end
