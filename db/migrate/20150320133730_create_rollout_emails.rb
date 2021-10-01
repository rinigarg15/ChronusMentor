class CreateRolloutEmails< ActiveRecord::Migration[4.2]
  def change
    create_table :rollout_emails do |t|
      t.integer :ref_obj_id
      t.string :ref_obj_type, limit: UTF8MB4_VARCHAR_LIMIT
      t.string :email_id
      t.timestamps null: false
    end

    add_index :rollout_emails, [:ref_obj_id, :ref_obj_type]
  end
end
