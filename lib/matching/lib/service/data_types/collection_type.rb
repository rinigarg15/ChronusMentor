module Matching
  # A <code>AbstractType</code> that serves as the base class for all those
  # types that represent collection of items.
  class CollectionType < AbstractType
    attr_accessor :items

    def initialize(items)
      self.items = items
    end

    def self.get_marshalled_data(instance)
      instance.items.to_a
    end

    def self.create_object_from_marshalled_data(value)
      self.new(value)
    end

    #
    # Relative weights to apply for individual fields of the collection.
    # 
    # To be implemented by the subclasses.
    #
    def field_weights
      raise NotImplementedError
    end

    # Given a list of field names of an active record object type and two arrays
    # of objects of that type, computes the overall distance of the values
    # present in the objects normalized to the range 0..1.
    #
    def do_match(other_field, options = {})
      # Initialize the values map, creating an array entry for each of the field
      # names.
      collective_values = [{}, {}]

      # Now, push values of each of the objects in the two arrays into the
      # collective_values array.
      field_weights.keys.each do |field_name|
        # new_field_name is used in case of on the fly matching between two questions
        new_field_name = field_name.to_sym
        collective_values[0][field_name] = self.items.collect{|item| item[new_field_name].try(:downcase)}
        collective_values[1][field_name] = other_field.items.collect{|item| item[new_field_name].try(:downcase)}
      end

      # Combine all values of the same field into a string and compute the
      # textual distance between those values of obj_arr_1 and obj_arr_2.
      total_distance = 0
      common_values = []
      field_weights.each_pair do |field_name, weight|
        dist = array_distance(
          collective_values[0][field_name],
          collective_values[1][field_name], options)
        if options[:get_common_data]
          common_values << dist[:common_values]
          dist = dist[:score]
        end
        total_distance = total_distance+(dist * weight)
      end

      # Normalize to 0..1, dividing by the number of fields.
      score = total_distance.to_f / field_weights.values.sum
      get_score_or_hash(score, options.merge(common_values: common_values))
    end
  end
end
