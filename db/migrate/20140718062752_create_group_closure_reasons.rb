class CreateGroupClosureReasons< ActiveRecord::Migration[4.2]
  def change
    create_table :group_closure_reasons do |t|
      t.string  :reason
      t.boolean :is_deleted, default: false
      t.boolean :is_completed, default: false
      t.boolean :is_default, default: false
      t.belongs_to :program, null: false
      t.timestamps null: false
    end
    add_index :group_closure_reasons, [:program_id]
  end
end