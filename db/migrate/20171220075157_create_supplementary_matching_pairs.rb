class CreateSupplementaryMatchingPairs< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :supplementary_matching_pairs do |t|
        t.integer :mentor_role_question_id, null: false
        t.integer :student_role_question_id, null: false
        t.integer :program_id, null: false

        t.timestamps null: false
      end
      add_index :supplementary_matching_pairs, :program_id
      add_index :supplementary_matching_pairs, :mentor_role_question_id
      add_index :supplementary_matching_pairs, :student_role_question_id
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :supplementary_matching_pairs
    end
  end
end
