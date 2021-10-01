module Matching
  module Database
    class Score < MatchingDatabase

      def initialize
        super(Matching::Persistence::Score.collection)
      end

      def find_by_mentee_id(mentee_id)
        @collection.find({:student_id => mentee_id})
      end

      def find_by_mentee_array_and_partition_id(mentees_array, partition_id)
        @collection.find({:student_id => {"$in" => mentees_array }, :p_id => partition_id})
      end

      def get_min_max_by_mentee_id(mentee_id)
        temp_min, temp_max = Float::INFINITY, -1*Float::INFINITY 
        student_docs = find_by_mentee_id(mentee_id)
        student_docs.each do |student_cache|
          student_scores = student_cache["mentor_hash"].values
          student_scores.each do |value|
            temp_min = value[0] if value[0] < temp_min
            temp_max = value[0] if value[0] > temp_max
          end
        end
        temp_min, temp_max = nil, nil if temp_min == Float::INFINITY
        [temp_min, temp_max]
      end

      #--Returns complete mentor hash by clubbing all partition score documents of mentee
      def get_mentor_hash(mentee_id)
        mentor_hash = {}
        find_by_mentee_id(mentee_id).each do |partition_doc|
          mentor_hash.merge!(partition_doc["mentor_hash"])
        end
        mentor_hash
      end
    end
  end
end