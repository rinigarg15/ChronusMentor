module Matching
  module Database
    #--Bulk Score class used for bulk insert and update documents
    class BulkScore < MatchingDatabase
      attr_accessor :bulk_operations

      def initialize
        super(Matching::Persistence::Score.collection)
        self.bulk_operations = []
      end

      def find(*)
        raise NotImplementedError
      end

      def update(find, set, options = {upsert: false})
        @bulk_operations << {
          update_one:
          {
            filter: find,
            update: { '$set' => set},
            upsert: options[:upsert]
          }
        }
      end

      def delete(find, unset)
        @bulk_operations << {
          update_one:
          {
            filter: find,
            update: { '$unset' => unset}
          }
        }
      end

      def insert(options)
        @bulk_operations << {
          insert_one: options
        }
      end

      def execute
        @collection.bulk_write(@bulk_operations, ordered: false) if @bulk_operations.any?
      end
      
    end
  end
end