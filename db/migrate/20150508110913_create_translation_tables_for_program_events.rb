class CreateTranslationTablesForProgramEvents< ActiveRecord::Migration[4.2]
  def up
    ProgramEvent.create_translation_table!({
      :title => :string,
      :description => :text
    },
    {
      :migrate_data => true
    })
  end

  def down
    ProgramEvent.drop_translation_table! :migrate_data => true
  end
end
