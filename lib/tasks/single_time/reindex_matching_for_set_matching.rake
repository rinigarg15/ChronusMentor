#usage rake single_time:reindex_matching_for_set_matching
#Example rake single_time:reindex_matching_for_set_matching

namespace :single_time do
  desc "Reindex matching for programs with set matching match configs"
  task reindex_matching_for_set_matching: :environment do
    pids = MatchConfig.where(matching_type: MatchConfig::MatchingType::SET_MATCHING).pluck(:program_id).uniq
    Program.active.where(id: pids).pluck(:id).each do |program_id|
      Matching.perform_program_delta_index_and_refresh_with_error_handler(program_id)
    end
  end
end