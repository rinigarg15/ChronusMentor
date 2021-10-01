class CreateGroupViews< ActiveRecord::Migration[4.2]
  def change
    create_table :group_views do |t|
      t.belongs_to :program, null: false
      t.timestamps null: false
    end
    add_index :group_views, :program_id
  end
end
