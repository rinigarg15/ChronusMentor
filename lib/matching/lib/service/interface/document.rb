module Matching
  module Interface
    class Document

      attr_accessor :record_id, :program_id, :mentor, :data_fields, :hit_count, :original_score, :score, :not_match, :data_fields_by_name

      def initialize(document)
        self.data_fields            = build_data_fields(document["data_fields"] || [])
        self.data_fields_by_name    = {}
        self.compute_data_fields_by_name!

        self.mentor                 = document["mentor"] || []
        self.program_id             = document["program_id"] || []
        self.record_id              = document["record_id"] || []
        self.hit_count              = 0
        self.score                  = 0
        self.not_match              = false
      end

      def compute_data_fields_by_name!
        self.data_fields.each do |data_field|
          self.data_fields_by_name[data_field.name] = data_field
        end
      end

      def build_data_fields(data_fields)
        data_fields.collect do |data_field|
          Matching::Interface::DataField.new(data_field)
        end
      end

      # Returns the data field with the given name.
      def get_data_field_by_name(name)
        self.data_fields_by_name[name]
      end

      alias :get_field :get_data_field_by_name

      # Resets hit count and score to 0.
      def reset_scores!
        self.hit_count  = 0
        self.score      = 0
      end
    end
  end
end
