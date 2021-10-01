module Matching
  module Interface
    #
    # A field in the Matching::Interface::Document that <b>can be matched</b>
    # with other <code>Matching::Interface::DataField</code>s
    #
    class DataField

      attr_accessor :name, :value, :match_val

      @@data_types = {
        "Matching::AbstractType"          =>    Matching::AbstractType,
        "Matching::ChronusOrderedArray"   =>    Matching::ChronusOrderedArray,
        "Matching::ChronusArray"          =>    Matching::ChronusArray,
        "Matching::ChronusEducations"     =>    Matching::ChronusEducations,
        "Matching::ChronusExperiences"    =>    Matching::ChronusExperiences,
        "Matching::ChronusLocation"       =>    Matching::ChronusLocation,
        "Matching::ChronusString"         =>    Matching::ChronusString,
        "Matching::ChronusText"           =>    Matching::ChronusText,
        "Matching::CollectionType"        =>    Matching::CollectionType,
        "Matching::ChronusMisMatch"       =>    Matching::ChronusMisMatch
      }

      # Constructor
      def initialize(data_field)
        # name/:name and value/:value -> for handling backward compatibility during Rails 5 upgrade
        self.name = data_field["name"].presence || data_field[":name"]
        self.value = build_value(data_field["value"].presence || data_field[":value"])
        self.match_val  = 0
      end

      def build_value(value)
        get_data_type(value[0]).new(value[1])
      end

      def get_data_type(data_type)
        @@data_types[data_type]
      end

      def match(other_field, options = {})
        self.match_val = self.value.match(other_field.value, options)
      end

      def is_of_type?(class_name)
        self.value.is_a?(class_name)
      end
    end
  end
end