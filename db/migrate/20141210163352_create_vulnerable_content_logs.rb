class CreateVulnerableContentLogs< ActiveRecord::Migration[4.2]
  def change
    create_table :vulnerable_content_logs do |t|
      t.text :original_content
      t.text :sanitized_content
      t.integer :member_id
      t.integer :ref_obj_id
      t.string :ref_obj_type
      t.string :ref_obj_column

      t.timestamps null: false
    end
  end
end
