namespace :single_time do
  #usage: bundle exec rake single_time:handle_invalid_match_configs
  desc "Handling match configs with incompatible question types"
  task handle_invalid_match_configs: :environment do
    Program.includes(:translations, match_configs: [student_question: {profile_question: :translations}, mentor_question: {profile_question: :translations}]).each do |program|
      program_reindexing_needed = false
      program.match_configs.each do |match_config|
        mentor_question = match_config.mentor_question
        student_question = match_config.student_question
        is_compatible_question = mentor_question.is_compatible_for_matching_with?(student_question, match_config.matching_type)
        unless is_compatible_question
          if match_config.matching_type == MatchConfig::MatchingType::SET_MATCHING
            match_config.update_attribute(:matching_type, MatchConfig::MatchingType::DEFAULT)
            program_reindexing_needed = true
          end
        end
      end
      Matching.perform_program_delta_index_and_refresh(program.id) if program_reindexing_needed
    end
    puts "Done!"
  end
end
