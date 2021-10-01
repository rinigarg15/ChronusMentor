class CreateDateAnswers < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      create_table :date_answers do |t|
        t.date :answer
        t.references :ref_obj, polymorphic: { limit: UTF8MB4_VARCHAR_LIMIT }, index: true
  
        t.timestamps
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :date_answers
    end
  end
end
