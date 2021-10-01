class CreateAnswerChoiceVersions < ActiveRecord::Migration[5.1]
  TEXT_BYTES = 1_073_741_823
  def up
    ChronusMigrate.ddl_migration do
      create_table :answer_choice_versions do |t|
        t.string   :item_type, {null: false, limit: UTF8MB4_VARCHAR_LIMIT}
        t.integer  :item_id, null: false, index: true
        t.integer  :member_id, index: true
        t.integer  :question_choice_id, index: true
        t.string   :event, null: false
        t.string   :whodunnit
        t.text     :object, limit: TEXT_BYTES
        t.text     :object_changes, limit: TEXT_BYTES
        t.timestamps null: false
      end
      add_index :answer_choice_versions, [:item_id, :item_type]
      add_index :answer_choice_versions, [:member_id, :question_choice_id]

      max_answer_choice_id = AnswerChoice.maximum(:id).to_i
      start_id = 0
      while start_id <= max_answer_choice_id do
        end_id = start_id + 99999
        end_id = max_answer_choice_id if end_id > max_answer_choice_id
        AnswerChoice.delay(priority: DjPriority::NON_BLOCKING_BULK_CREATE).bulk_create_initial_versions(start_id, end_id)
        start_id = end_id + 1
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :answer_choice_versions
    end
  end
end
