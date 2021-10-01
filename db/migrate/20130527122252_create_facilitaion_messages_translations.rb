class CreateFacilitaionMessagesTranslations< ActiveRecord::Migration[4.2]
  def up
    # Dummy table creation to make sure the generate fixtures doesn't have issues
    create_table :facilitation_message_translations do |t|
      t.timestamps null: false
    end

    # FacilitationMessage.create_translation_table!({
    #   subject: :string,
    #   message: :text
    # }, {
    #   migrate_data: true
    # })
  end

  def down
    # FacilitationMessage.drop_translation_table! migrate_data: true
  end
end
