module Matching
  module Persistence
    class Setting
      include Mongoid::Document
      store_in collection: "matching.persistence.settings"
      field :min_match_score, type: Float
      field :max_match_score, type: Float
      field :program_id,  type: Integer
      field :partition, type: Integer, default: 1
      field :dynamic_p, type: Boolean, default: false 

      validates_presence_of :program_id
      index({ program_id: 1 })
    end
  end
end