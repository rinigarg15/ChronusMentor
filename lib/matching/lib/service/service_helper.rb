module Matching
  module ServiceHelper
    #--Generates unique string used for dynamic partitioning
    def get_unique_stamp
      Time.now.to_i.to_s + (rand() * 10).to_s
    end

    def measure(comment)
      ActiveRecord::Base.benchmark comment do 
        yield
      end
    end

    def update_match_score_range_for_mentor_update!(program, min_score, max_score)
      unless min_score == Float::INFINITY
        program.update_match_scores_range_for_min_max!(min_score, max_score)
      else
        #Do Nothing
      end
    end

    #--Used for creating hash of ids based on divisor
    #--Hash = {0 => [id1, id2], 1 => [id3, id4]} where 0 == id1%divisor 
    def get_ids_hash_based_on_modulo(user_ids, divisor)
      ids_hash = {}
      user_ids.each do |user_id|
        ids_hash[user_id % divisor] = [] if ids_hash[user_id % divisor].nil?
        ids_hash[user_id % divisor] << user_id
      end
      ids_hash
    end
  end
end