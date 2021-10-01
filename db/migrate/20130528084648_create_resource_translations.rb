class CreateResourceTranslations< ActiveRecord::Migration[4.2]
  def up
    Resource.create_translation_table!({
      title: :string,
      content: :text
    }, {
      migrate_data: true
    })
  end

  def down
    Resource.drop_translation_table! migrate_data: true
  end
end
