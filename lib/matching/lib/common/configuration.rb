module Matching
  #
  # Matching configuration that the service uses to do perform matching.
  #
  class Configuration
    # Default value for the mappings.
    DEFAULT_WEIGHT = 1

    # A <code>Hash</code> map used for holding the field mappings in a symmetric
    # fashion i.e., if field_1 is mapped to field_2, field_2
    # <i>will</i> be mapped to field_1.
    attr_accessor :field_mappings

    # Constuctor
    def initialize
      self.field_mappings = Hash.new
    end

    # Returns a combined string for the given <i>field_spec</i>, which is an
    # array containing the <code>ActiveRecord</code> model classes in the order
    # of association, followed by the last model's field name.
    #
    #   Configuration.name_from_field_spec([Land, 'size']) #=> land_size
    #   Configuration.name_from_field_spec([Land, Tree, Fruit, 'name']) #=> land_tree_fruit_name
    #
    def self.name_from_field_spec(field_spec)
      field_entries = field_spec[0..-2].collect{|m| m.name.underscore}
      field_entries << field_spec.last.gsub(' ', '_').downcase # last model's field name.
      field_entries.join('_')
    end

    # Creates the mapping pair [field_spec_1, field_spec_2] with the given +weight+.
    def add_mapping(field_spec_1, field_spec_2, weight_and_threshold_and_details)
      field_1 = self.class.name_from_field_spec(field_spec_1)
      field_2 = self.class.name_from_field_spec(field_spec_2)
      self.field_mappings[[field_1, field_2]] = weight_and_threshold_and_details
    end

    # Maximum hit_count that a document can attain. This is nothing but the
    # summation of the weights of all the fields that are participating in the
    # match. Returns 0 when there are no weights
    #
    def max_hits
      self.field_mappings.values.collect(&:first).collect(&:abs).sum
    end
  end
end
