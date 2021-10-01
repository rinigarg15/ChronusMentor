class AddScrapFieldsToMessages< ActiveRecord::Migration[4.2]
  def change
    add_column :messages, :posted_via_email, :boolean, default: false
    add_column :messages, :reply_within, :integer
    add_column :messages, :attachment_file_name, :string
    add_column :messages, :attachment_content_type, :string
    add_column :messages, :attachment_file_size, :integer
    add_column :messages, :attachment_updated_at, :datetime
    add_column :messages, :old_scrap_id, :integer
    add_column :messages, :old_message_id, :integer
  end
end
