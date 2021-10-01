module Matching
  # A <code>CollectionType</code> for matching a list of educations.
  class ChronusEducations < CollectionType

    def no_data?
      self.items.blank?
    end

    # Relative weights to apply for individual fields of each education.
    def field_weights
      {'school_name' => 0.3, 'major' => 0.7}
    end
  end
end