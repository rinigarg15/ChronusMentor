namespace :single_time do

  # time bundle exec rake single_time:migrate_answer_text_to_answer_choice
  desc 'Migrate answer_text in ProfileAnswer to AnswerChoice model'
  task :migrate_answer_text_to_answer_choice => :environment do
    MigrateAnswerTextToAnswerChoice.new.migrator
  end

  # time bundle exec rake single_time:migrate_common_answer_text_to_answer_choice
  desc 'Migrate answer_text in CommonAnswer to AnswerChoice model'
  task :migrate_common_answer_text_to_answer_choice => :environment do
    MigrateCommonAnswerTextToAnswerChoice.new.migrator
  end

  # time bundle exec rake single_time:migrate_delta_common_answer_text_to_answer_choice DELTA_IDS="1,2,3"
  desc 'Migrate delta answer_text in CommonAnswer to AnswerChoice model'
  task :migrate_delta_common_answer_text_to_answer_choice => :environment do
    delta_ids = ENV["DELTA_IDS"].split(",").map(&:to_i)
    MigrateCommonAnswerTextToAnswerChoice.new.migrate_delta_answer_to_answer_choices(delta_ids)
  end

end
