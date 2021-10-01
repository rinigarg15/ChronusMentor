class CreateSummaries < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :summaries do |t|
        t.integer :connection_question_id, index: true
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :summaries
    end
  end
end
