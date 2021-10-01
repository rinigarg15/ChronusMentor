module Matching
  module Database
    class MatchingDatabase
      attr_accessor :collection

      def initialize(collection)
        self.collection = collection
      end

      def find(query_hash)
        @collection.find(query_hash)
      end

      def update(find, set)
        @collection.update_one(find, { :$set => set })
      end
    end
  end
end
