class CreateTableAnswerChoices< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :answer_choices do |t|
        t.references :ref_obj, polymorphic: true, index: true
        t.integer :question_choice_id
        t.integer :position, default: 0
        t.timestamps null: false
      end
      add_index :answer_choices, :question_choice_id
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :answer_choices
    end
  end
end
