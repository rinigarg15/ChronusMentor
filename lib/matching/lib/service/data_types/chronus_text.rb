module Matching
  # <code>AbstractType</code> for matching multi line strings.
  class ChronusText < AbstractType
    attr_accessor :text

    def initialize(text)
      self.text = text
    end

    def value
      self.text
    end

    def no_data?
      self.text.blank?
    end

    def self.get_marshalled_data(instance)
      instance.text
    end

    def self.create_object_from_marshalled_data(text)
      self.new(text)
    end

    #
    # Implementation of <code>AbstractType#do_match</code>.
    # Delegates to <code>AbstractType#text_distance</code>
    #
    def do_match(other_field, options = {})
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