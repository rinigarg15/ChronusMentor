class CreatePreferenceBasedMentorLists < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :preference_based_mentor_lists do |t|
        t.references  :user, index: true
        t.references  :ref_obj, polymorphic: { limit: UTF8MB4_VARCHAR_LIMIT }, index: {:name => "index_pbmls_ref_obj"}
        t.references  :profile_question, index: true
        t.boolean     :ignored
        t.float       :weight
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :preference_based_mentor_lists
    end
  end
end
