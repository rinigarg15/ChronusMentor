class CreateTranslationTablesForAnnouncements< ActiveRecord::Migration[4.2]
  def up
    Announcement.create_translation_table!({
      :title => :string,
      :body => :text
    }, {
      :migrate_data => true
    })
  end

  def down
    Announcement.drop_translation_table! :migrate_data => true
  end
end
