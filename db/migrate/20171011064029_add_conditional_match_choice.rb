class AddConditionalMatchChoice< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :conditional_match_choices do |t|
        t.references :question_choice, index: true
        t.references :profile_question, index: true

        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :conditional_match_choices
    end
  end
end
