class CreateFeedExporters< ActiveRecord::Migration[4.2]
  def up
    create_table :feed_exporters do |t|
      t.integer :program_id
      t.float :frequency, default: 1
      t.integer :mime_type, default: 0
      t.string  SOURCE_AUDIT_KEY.to_sym,  limit: UTF8MB4_VARCHAR_LIMIT
    end
  end

  def down
    drop_table :feed_exporters
  end
end