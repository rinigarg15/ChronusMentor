module Matching
  # A <code>CollectionType</code> for matching a list of experiences.
  class ChronusExperiences < CollectionType

    def no_data?
      self.items.blank?
    end

    # Relative weights to apply for individual fields of each experience.
    def field_weights
      {'job_title' => 0.5, 'company' => 0.5}
    end
  end
end
