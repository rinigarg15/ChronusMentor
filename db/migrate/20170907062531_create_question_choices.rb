class CreateQuestionChoices< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      create_table :question_choices do |t|
        t.text :text
        t.boolean :is_other, default: false
        t.integer :position, default: 0
        t.references :ref_obj, polymorphic: true, index: true

        t.timestamps null: false
      end
      add_index :question_choices, :text, length: UTF8MB4_VARCHAR_LIMIT
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :question_choices
    end
  end
end
