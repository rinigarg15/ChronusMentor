module HealthReport
  # Metric that can represented as percentage of a given range.
  class PercentMetric < AbstractMetric
    attr_accessor :maximum    # Minimum value of the metric
    attr_accessor :minimum    # Maximum value of the metric
    attr_accessor :threshold  # Threshold below which the metric is considered bad
    attr_accessor :unit       # String representing the unit of the metric.
    attr_accessor :current    # Current value
    attr_accessor :value      # Effective percentage value.
    attr_accessor :inverted   # Compute the metric in inverted mode, where the maximum
    attr_accessor :no_data    # Whether there is not enough data for this report.
    alias_method :no_data?, :no_data

    # Value +around+ the threshold which is considered 'Average'.
    THRESHOLD_WINDOW = 0.05

    # Inference texts for this metric.
    GOOD            = 'Good'
    AVERAGE         = 'Average'
    NEEDS_ATTENTION = 'Needs Attention'

    def translated_texts
      {
        GOOD => "percent_metric.good".translate,
        AVERAGE => "percent_metric.average".translate,
        NEEDS_ATTENTION => "percent_metric.needs_attention".translate
      }
    end
    # Constructor.
    #
    # Params:
    # * <tt>threshold</tt> : the threshold of this metric
    # * <tt>attrs</tt> : Hash with values for the keys :minimum, :maximum, :unit,
    #   :inverted
    #
    def initialize(threshold, attrs = {})
      self.threshold  = threshold
      self.minimum    = attrs[:minimum] || 0.0 # Default minimum to 0.0
      self.maximum    = attrs[:maximum] || 1.0 # Default maximum to 1.0
      self.unit       = attrs[:unit]
      self.inverted   = attrs[:inverted]
    end

    # Returns the effective value by scaling based on the +minimum+ and +maximum+
    # range.
    def effective_value
      val = self.inverted ? (1 - self.value) : self.value
      val = (self.maximum - self.minimum) * val

      # For percent based metric, multiple by 100.
      val = (val * 100) if percent_based?
      val.round(2)
    end

    # The metric has no data if current is not set or set to nil.
    def no_data?
      self.current.nil?
    end

    # Returns whether this metric is using (0..1) as the bounds.
    def percent_based?
      self.minimum == 0.0 && self.maximum == 1.0
    end

    # Value range that we consider +GOOD+ for +this+ metric.
    def average_range
      # normalized_threshold +/- THRESHOLD_WINDOW
      Range.new((normalized_threshold - THRESHOLD_WINDOW), (normalized_threshold + THRESHOLD_WINDOW))
    end

    # Converts threshold to 0..1 range.
    def normalized_threshold
      t = self.threshold.to_f / (self.maximum - self.minimum)
      t = 1.0 - t if self.inverted # Negate for inverted metrics.
      return t
    end

    # Returns the inference string of this metric
    def inference_display
      translated_texts[inference]
    end

    def inference
      # Value around the threshold window?
      if average_range.include?(self.value)
        return AVERAGE
      elsif self.value < normalized_threshold
        # Value on the left side of threshold window?
        return NEEDS_ATTENTION
      elsif self.value > normalized_threshold
        # Value on the right side of threshold window?
        return GOOD
      end
    end

    # Returns whether this metric is having a good value.
    def good?
      inference == GOOD
    end

    # Returns whether this metric is having an average value.
    def average?
      inference == AVERAGE
    end

    # Returns whether this metric is having a value that needs attention.
    def needs_attention?
      inference == NEEDS_ATTENTION
    end

    def progress_class
      self.good? ? "progress-bar" : (self.average? ? "progress-bar-warning" : "progress-bar-danger")
    end

    def text_class
      self.good? ? "green" : (self.average? ? "dim" : "red")
    end

    # Updates the metric by setting the current value
    def update_metric(cur)
      # If cur is nil, it means no data. Set value to 0.0 and return.
      if cur.nil?
        self.no_data = true
        self.value = 0.0
        return
      end

      self.current = cur

      # If current is +greater+ than maximum, set current to
      # maximum so as to keep the value under bounds.
      self.current = [self.current, self.maximum].min
      full_range = self.maximum - self.minimum

      # If full_range is 0.0, set the value to that so as to avoid divide by zero.
      if full_range.zero?
        self.value = self.minimum
      else
        # Use the offsets from minimum to find the percentage.
        self.value = (self.current - self.minimum).to_f / full_range
      end

      # Compute the complement for inverted metrics.
      self.value = 1.0 - self.value if self.inverted
    end
  end
end
