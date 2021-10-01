module Matching
  # <code>AbstractType</code> for matching simple one line strings.
  class ChronusString < AbstractType
    attr_accessor :string

    def initialize(string)
      self.string = string
    end

    def value
      self.string
    end

    def no_data?
      self.string.blank?
    end

    def self.get_marshalled_data(instance)
      instance.string
    end

    def self.create_object_from_marshalled_data(string)
      self.new(string)
    end

    # Implementation of <code>AbstractType#do_match</code>
    def do_match(other_field, options = {})
      if options[:matching_details].present?
        # matching details is present only in case of set mapping and tha too for choice based questions
        return set_matching([self.value], other_field.value, options)
      else
        other_value = other_field.value
        if other_field.is_a?(Matching::ChronusArray)
          string_array_distance(self.value, other_value, options)
        elsif other_field.is_a?(Matching::ChronusOrderedArray)
          string_ordered_array_distance(self.value, other_value, options)
        else
          text_distance(self.value, other_value.to_s, options)
        end
      end
    end
  end
end