class MigrateQuestionInfoAndAnswerTextToChoices< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      puts "Migrating Question Info to Question Choices"
      Rake::Task['single_time:migrate_question_info_to_question_choice'].invoke

      puts "Migrating Answer Text to Answer Choices"
      MigrateAnswerTextToAnswerChoice.new.migrator
    end
  end

  def down
  end
end
