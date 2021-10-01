class CreateExplicitUserPreferences < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :explicit_user_preferences do |t|
        t.integer :preference_weight, default: ExplicitUserPreference::PriorityValues::IMPORTANT
        t.references :user
        t.references :role_question
        t.boolean :from_match_config, default: false

        t.timestamps null: false
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :explicit_user_preferences
    end
  end
end
