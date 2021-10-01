class CreateUserSearchActivity < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :user_search_activities do |t|
        t.references  :program, index: true
        t.references  :user, index: true
        t.references  :profile_question, index: true
        t.references  :question_choice, index: true
        t.string      :locale
        t.text        :profile_question_text
        t.text        :search_text
        t.integer     :source
        t.string      :session_id, index: true
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :user_search_activities
    end
  end
end