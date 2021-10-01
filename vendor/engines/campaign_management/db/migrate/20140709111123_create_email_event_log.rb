class CreateEmailEventLog < ActiveRecord::Migration[4.2]

  def up
    create_table :cm_email_event_logs do |t|
      t.belongs_to :admin_message, null: false
      t.integer :event_type, null: false
      t.datetime :timestamp
      t.text :params
      t.string SOURCE_AUDIT_KEY.to_sym, :limit => UTF8MB4_VARCHAR_LIMIT
    end
    add_index :cm_email_event_logs, :admin_message_id
  end

  def down
  end
end
