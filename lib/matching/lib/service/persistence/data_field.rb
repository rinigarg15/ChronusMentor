module Matching
  module Persistence
    #
    # A field in the MatchingDocument that <b>can be matched</b>
    # with other <code>Matching::Persistence::DataField</code>s
    #
    class DataField
      #------------------------------------------------------------------------
      # ATTRIBUTES
      #------------------------------------------------------------------------

      # The match computed (0..1) by comparing this field with another field of
      # another document.
      # here :value is Matching::AbstractType
      #
      attr_accessor :name, :value, :match_val

      #
      # Constructs a new Matching::DataField for the given +field_spec+ with the
      # given +value+
      #
      def self.construct_from_field_spec(field_spec, value)
        name = field_spec.is_a?(Array) ? Configuration.name_from_field_spec(field_spec) : field_spec
        name = name.gsub(' ', '_').downcase

        Matching::Persistence::DataField.new({:name => name, :value => value})
      end

      # Constructor
      def initialize(*attrs)
        self.name = attrs.first[:name]
        self.value = attrs.first[:value]
        self.match_val  = 0
      end

      # Performs a match with the given field and returns a value from 0 to 1,
      # where 0 indicates no match at all, and 1, best match.
      #
      # In future, we can change this function to return negative to indicate an
      # incompatibility a for strong preference, say Gender => Male
      #
      # We apply the comparison operators based on this field's type. Following
      # are a few code examples, where the ranges are of type
      # <code>Matching::Range</code>, integers of type
      # <code>Matching::Integer</code> and so on...
      #
      # * Age comparison involving ranges and numbers
      #   (18..25).match_values(20)     #=> 1
      #   (30..55).match_values(20..50) #=> 1
      #   (30..25).match_values(18..20) #=> 1
      #
      # * Language comparison with arrays
      #   ['English', 'Tamil', 'French'].match_values(['Tamil', 'French']) #=> 2
      #   ['English', 'Tamil', 'French'].match_values('Tamil')             #=> 1
      #
      def match(other_field, options = {})
        self.match_val = self.value.match(other_field.value, options)
      end

      def is_of_type?(class_name)
        self.value.is_a?(class_name)
      end
    end
  end
end