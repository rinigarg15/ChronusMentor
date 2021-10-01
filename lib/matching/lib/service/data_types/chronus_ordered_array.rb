module Matching
  # <code>AbstractType</code> equivalent of ruby <code>Array</code> with Priority
  class ChronusOrderedArray < AbstractType
    attr_accessor :collection

    def initialize(collection)
      self.collection = collection
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
      ChronusOrderedArray.new(value)
    end

    #
    # Implementation of <code>AbstractType#do_match</code>.
    #
    # Returns a number in the 0..1 range representing the number of common points
    # with respect to priority between the two ordered arrays.
    #
    def do_match(other_field, options = {})
      if options[:matching_details].present?
        # matching details is present only in case of set mapping and tha too for choice based questions
        return set_matching(self.value, other_field.value, options)
      else
        other_value = other_field.value

        if other_value.is_a?(String) 
          string_ordered_array_distance(other_value, self.value, options)
        elsif other_field.is_a?(Matching::ChronusArray)
          array_ordered_array_distance(self.value, other_value, 0, options)
        elsif other_field.is_a?(Matching::ChronusOrderedArray)
          ordered_array_distance(self.value, other_value, options)
        end
      end
    end
  end
end