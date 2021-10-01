class RemoveReplyWithinColumnFromScrap< ActiveRecord::Migration[4.2]
  def up
    remove_column :messages, :reply_within
  end

  def down
    add_column :messages, :reply_within, :integer
  end
end
