class CreateProgramEventUsers< ActiveRecord::Migration[4.2]
  def change
    create_table :program_event_users do |t|
      t.references :user
      t.references :program_event
      t.string SOURCE_AUDIT_KEY.to_sym, limit: UTF8MB4_VARCHAR_LIMIT
    end
    add_index :program_event_users, :user_id
    add_index :program_event_users, :program_event_id
  end
end
