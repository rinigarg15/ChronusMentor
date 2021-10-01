class MigrateCommonQuestionInfoAndAnswerTextToChoices< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      puts "Migrating Question Info to Question Choices"
      MigrateCommonQuestionInfoToQuestionChoice.new.migrator

      puts "Migrating Answer Text to Answer Choices"
      MigrateCommonAnswerTextToAnswerChoice.new.migrator
    end
  end

  def down
    # do nothing
  end
end
