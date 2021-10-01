class CreateProgramAbTests< ActiveRecord::Migration[4.2]
  def change
    create_table :program_ab_tests do |t|
      t.string :test, limit: UTF8MB4_VARCHAR_LIMIT
      t.integer :program_id
      t.boolean :enabled
      t.timestamps null: false
    end

    add_index :program_ab_tests, :test
    add_index :program_ab_tests, :program_id
  end
end
