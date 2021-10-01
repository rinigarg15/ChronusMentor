# TODO
# no_data?
#
module HealthReport
  # Metric that can represented as percentage of a given range.
  class DistributedMetric < AbstractMetric
    # Raised when the distribution does not sum up to 100%.
    class InvalidDistributionError < StandardError
    end

    class Component
      attr_accessor :name   # Name of this component
      attr_accessor :value  # Share of this component

      def initialize(name)
        self.name = name
        self.value = 0.0
      end
    end

    attr_accessor :components # Collection of components composing this metric
    attr_accessor :component_name_map

    # Constructor.
    #
    # Params:
    # * <tt>component_names</tt> : Array of names of the components.
    #
    def initialize(component_names)
      self.components = []
      self.component_name_map = {}
      component_names.each do |name|
        component = Component.new(name)
        self.components << component
        self.component_name_map[name] = component
      end
    end

    # Retrurns the distribution values as a map from name to value.
    def distribution
      value_map = ActiveSupport::OrderedHash.new
      self.components.collect do |component|
        value_map[component.name] = component.value
      end

      return value_map
    end

    # Returns the value of the component with the given name
    def value_for_component(name)
      self.component_name_map[name].value
    end

    # Returns true if there is no data in this metric.
    def no_data?
      self.components.collect(&:value).sum == 0
    end

    # Updates the distribution with the values in the map.
    #
    # Params:
    # * <tt>map</tt> : Hash map from component name to new value for it.
    #
    def update_metric(values_map)
      # The sum must be 1.0
      raise InvalidDistributionError if values_map.values.sum.round(2) != 1.0

      self.component_name_map.each do |name, component|
        # If no value is given for a componenet, take it as 0.
        component.value = values_map[name] || 0.0
      end
    end
  end
end
