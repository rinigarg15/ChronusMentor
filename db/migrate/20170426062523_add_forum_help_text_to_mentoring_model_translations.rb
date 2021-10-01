class AddForumHelpTextToMentoringModelTranslations< ActiveRecord::Migration[4.2]
  include MigrationHelpers

  def up
    add_translation_column(MentoringModel, :forum_help_text, "text")

    ChronusMigrate.data_migration(has_downtime: false) do
      puts "Populating default forum help text in mentoring models"
      MentoringModel.all.includes(:translations).each_with_index do |mentoring_model, index|
        mentoring_model.populate_default_forum_help_text
        mentoring_model.save!
        print "." if ((index + 1) % 10 == 0)
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table MentoringModel.translations_table_name do |t|
        t.remove_column :forum_help_text
      end
    end
  end
end