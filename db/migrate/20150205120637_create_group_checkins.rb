class CreateGroupCheckins< ActiveRecord::Migration[4.2]
  def up
    create_table :group_checkins do |t|
      t.text :comment
      t.integer :checkin_ref_obj_id
      t.string :checkin_ref_obj_type, limit: UTF8MB4_VARCHAR_LIMIT
      t.integer :duration
      t.datetime :date
      t.integer :user_id
      t.integer :program_id
      t.timestamps null: false
    end
    add_index :group_checkins, :checkin_ref_obj_id
    add_index :group_checkins, :checkin_ref_obj_type
    add_index :group_checkins, :program_id
    add_index :group_checkins, :user_id
        
    Feature.new(:name => "contract_management").save! if Feature.count > 0
  end

  def down
    drop_table :group_checkins
    Feature.find_by(name: "contract_management").destroy
  end
end
