namespace :single_time do
  # bundle exec rake single_time:migrate_common_question_info_to_question_choice
  desc "Migrate commmon question's question_info to question_choices"
  task :migrate_common_question_info_to_question_choice => :environment do
    MigrateCommonQuestionInfoToQuestionChoice.new.migrator
  end

  # bundle exec rake single_time:verify_common_question_info_migration
  desc "Validate common questions's choices migrations"
  task verify_common_question_info_migration: :environment do
    MigrateCommonQuestionInfoToQuestionChoice.new.validator
  end

  # bundle exec rake single_time:migrate_delta_common_question_info_to_question_choice DELTA_IDS="1,2,3"
  desc "Migrate delta commmon question's question_info to question_choices"
  task :migrate_delta_common_question_info_to_question_choice => :environment do
    delta_ids = ENV["DELTA_IDS"].split(",").map(&:to_i)
    MigrateCommonQuestionInfoToQuestionChoice.new.migrate_delta_question_info_to_question_choices(delta_ids)
  end
end