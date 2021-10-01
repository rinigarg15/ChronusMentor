module Matching
  # <code>AbstractType</code> for matching locations.
  class ChronusLocation < AbstractType
    include Math

    attr_accessor :latitude
    attr_accessor :longitude

    def initialize(value)
      self.latitude = value[0]
      self.longitude = value[1]
    end

    def no_data?
      self.latitude.nil? || self.longitude.nil?
    end

    def self.get_marshalled_data(instance)
      [instance.latitude, instance.longitude]
    end

    def self.create_object_from_marshalled_data(value)
      self.new(value)
    end

    # Implementation of <code>AbstractType#do_match</code>. Computes the
    # distance between the given two locations and normalizes the value to the
    # range 0..1
    #
    # TODO: Compare based on city/state/country match?
    #
    def do_match(other_location, options = {})
      # If not enough information to compare, return 0 as the match.
      if self.no_data? || other_location.no_data?
        return 0
      else
        # Find in which range the distance falls into and assign weights
        # appropriately.
        case distance_in_miles(other_location)
        when 0..50;     return options[:get_common_data] ? {score: 1, common_values: [self.latitude, self.longitude]} : 1
        when 51..100;   return 0.75
        when 101..200;  return 0.5
        when 201..1000; return 0.25
        else;           return 0
        end
      end
    end

    # Returns the approximate distance in miles between the two locations.
    def distance_in_miles(other_location)
      x = 69.1 * (self.latitude - other_location.latitude)
      y = 53.0 * (self.longitude - other_location.longitude)

      sqrt(x * x + y * y)
    end
  end
end