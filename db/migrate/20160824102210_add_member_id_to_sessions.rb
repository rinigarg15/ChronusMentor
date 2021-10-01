class AddMemberIdToSessions< ActiveRecord::Migration[4.2]
  def change
    add_column :sessions, :member_id, :integer
    add_index :sessions, :member_id
  end
end
