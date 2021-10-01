class CreateEmailAnalytics< ActiveRecord::Migration[4.2]
  def up
    create_table :email_analytics do |t|
      t.string :campaign_id, :null => false, limit: UTF8MB4_VARCHAR_LIMIT
      t.integer :unique_link_clicked
      t.integer :unique_recipient_clicked
      t.integer :unique_recipient_opened
      t.integer :complained
      t.integer :delivered
      t.integer :clicked
      t.integer :opened
      t.integer :dropped
      t.integer :bounced
      t.integer :sent
      t.integer :unsubscribed
      t.timestamps null: false
    end
    add_index :email_analytics, :campaign_id
  end

  def down
    drop_table :email_analytics
  end
end
