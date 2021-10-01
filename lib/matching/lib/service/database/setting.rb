module Matching
  module Database
    class Setting < MatchingDatabase

      def initialize
        super(Matching::Persistence::Setting.collection)
      end
    end
  end
end