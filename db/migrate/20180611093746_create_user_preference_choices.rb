class CreateUserPreferenceChoices < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :user_preference_choices do |t|
        t.references :explicit_user_preference
        t.references :question_choice

        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :user_preference_choices
    end
  end
end
