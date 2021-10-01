module Matching
  # <code>AbstractType</code> equivalent of ruby <code>Array</code>
  class ChronusArray < AbstractType
    attr_accessor :collection

    def initialize(collection)
      self.collection = Array(collection)
    end

    def value
      self.collection
    end

    def no_data?
      self.collection.blank?
    end

    def self.get_marshalled_data(instance)
      instance.collection
    end

    def self.create_object_from_marshalled_data(value)
      ChronusArray.new(value)
    end

    #
    # Implementation of <code>AbstractType#do_match</code>.
    #
    # Returns a number in the 0..1 range representing the number of common points
    # between the two arrays.
    #
    def do_match(other_field, options = {})
      if options[:matching_details].present?
        # matching details is present only in case of set mapping and tha too for choice based questions
        return set_matching(self.value, other_field.value, options)
      else
        other_value = other_field.value

        # When trying to match an array with non-array (val2), first change val2
        # to an array by splitting it.
        if other_field.is_a?(Matching::ChronusArray)
          array_distance(self.value, other_value, options)
        elsif other_field.is_a?(Matching::ChronusOrderedArray)
          array_ordered_array_distance(self.value, other_value, 1, options)
        else        
          string_array_distance(other_value, self.value, options)
        end
      end
    end
  end
end