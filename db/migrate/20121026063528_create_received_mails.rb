class CreateReceivedMails< ActiveRecord::Migration[4.2]
  def up
  	create_table :received_mails do |t|
      t.string :message_id
      t.text :stripped_text
      t.string :from_email
      t.string :to_email
      t.text :data
      t.string :response
      t.boolean :sender_match
      t.string SOURCE_AUDIT_KEY.to_sym, limit: UTF8MB4_VARCHAR_LIMIT
    end
  end

  def down
  	drop_table :received_mails
  end
end