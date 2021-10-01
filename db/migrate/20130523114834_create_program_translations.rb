class CreateProgramTranslations< ActiveRecord::Migration[4.2]
  def up
    AbstractProgram.create_translation_table!({
      name: :string,
      description: :text
    }, {
      migrate_data: true
    })
  end

  def down
    AbstractProgram.drop_translation_table! migrate_data: true
  end
end
