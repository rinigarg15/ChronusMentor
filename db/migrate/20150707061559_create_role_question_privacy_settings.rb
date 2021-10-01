class CreateRoleQuestionPrivacySettings< ActiveRecord::Migration[4.2]
  def change
    create_table :role_question_privacy_settings do |t|
      t.references :role_question
      t.references :role
      t.integer :setting_type

      t.timestamps null: false
    end
    add_index :role_question_privacy_settings, :role_question_id
    add_index :role_question_privacy_settings, :role_id
  end
end
