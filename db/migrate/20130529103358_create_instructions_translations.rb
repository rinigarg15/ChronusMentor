class CreateInstructionsTranslations< ActiveRecord::Migration[4.2]
  def up
    AbstractInstruction.create_translation_table!({
      content: :text
    }, {
      migrate_data: true
    })
  end

  def down
    AbstractInstruction.drop_translation_table! migrate_data: true
  end
end
