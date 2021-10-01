module Matching
  module Interface
    class MenteeHash

      attr_accessor :mentor_id, :mentee_hash, :min_score, :max_score

      def initialize(mentor_id, mentees_size)
        self.mentor_id                              = mentor_id
        self.initialize_divisor_size(mentees_size)
        self.mentee_hash                            = {}
        self.initialize_empty_hash       
        self.min_score                              = Float::INFINITY
        self.max_score                              = -1*Float::INFINITY          
      end

      def initialize_divisor_size(mentees_size)
        @divisor = mentees_size/MAX_BULK_SIZE + 1
      end

      def initialize_empty_hash
        (0...@divisor).each do |div_id|
          mentee_hash[div_id] = {}
        end
      end

      def add_to_mentee_hash(mentee_id, score)
        mentee_hash[mentee_id % (@divisor)][mentee_id] = score
        update_min_max(score.first)
      end

      def update_min_max(score)
        self.min_score = score if score < self.min_score
        self.max_score = score if score > self.max_score
      end
    end
  end
end
