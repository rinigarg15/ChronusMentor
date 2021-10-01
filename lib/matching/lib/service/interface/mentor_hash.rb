module Matching
  module Interface
    class MentorHash

      attr_accessor :mentee_id, :mentor_hash_with_partition, :partition

      def initialize(mentee_id, partition)
        self.mentee_id                   = mentee_id
        self.partition                   = partition 
        self.mentor_hash_with_partition  = {}
        self.initialize_empty_hash
      end

      def initialize_empty_hash
        (0...self.partition).each do |partition_id|
          mentor_hash_with_partition[partition_id] = {}
        end
      end

      def add_to_mentor_hash(mentor_id, score)
        mentor_hash_with_partition[mentor_id % self.partition][mentor_id.to_s] = score
      end

      def get_mentor_hash_by_partition_id(partition_id)
        mentor_hash_with_partition[partition_id]
      end
    end
  end
end
