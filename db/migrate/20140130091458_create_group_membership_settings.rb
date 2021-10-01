class CreateGroupMembershipSettings< ActiveRecord::Migration[4.2]
  def up
    create_table :group_membership_settings do |t|
      t.belongs_to :group, :null => false
      t.belongs_to :role, :null => false
      t.integer :max_limit
      t.timestamps null: false
    end
    add_index :group_membership_settings, :group_id
    add_index :group_membership_settings, :role_id
  end

  def down
    remove_index :group_membership_settings, :group_id
    remove_index :group_membership_settings, :role_id
    drop_table :group_membership_settings
  end
end
