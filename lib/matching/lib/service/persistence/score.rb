module Matching
  module Persistence
    class Score
      include Mongoid::Document
      store_in collection: "matching.persistence.scores"
      field :student_id, :type => Integer
      field :p_id, :type => Integer, :default => 0
      field :t_s, :type => String, :default => "0" #t_s=timestamp used for dynamic patitioning
      field :mentor_hash

      validates_presence_of :student_id
      index({ student_id: 1 })
      index({ student_id: 1, p_id: 1 })
    end
  end
end