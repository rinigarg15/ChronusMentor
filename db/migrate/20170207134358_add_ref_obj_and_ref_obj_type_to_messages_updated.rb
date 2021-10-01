class AddRefObjAndRefObjTypeToMessagesUpdated< ActiveRecord::Migration[4.2]
  def self.up
    sql = ActiveRecord::Base.connection()
    sql.execute "SET autocommit=0"
    sql.begin_db_transaction
    sql.execute("CREATE TABLE messages_new LIKE messages")
    add_column :messages_new, :ref_obj_id, :integer
    add_column :messages_new, :ref_obj_type, :string, limit: UTF8MB4_VARCHAR_LIMIT
    sql.execute("INSERT INTO messages_new SELECT *, NULL, NULL FROM messages")
    rename_table :messages, :messages_old
    rename_table :messages_new, :messages
    sql.commit_db_transaction
    sql.execute "SET autocommit=1"
    Scrap.update_all("ref_obj_id = group_id, ref_obj_type='Group'")
  end
  
  def self.down
    drop_table :messages
    rename_table :messages_old, :messages
  end
end
