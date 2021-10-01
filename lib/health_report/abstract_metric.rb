module HealthReport
  # Interface for all kinds of metrics. Provides a single method +update_metric+.
  class AbstractMetric
    # Updates the metric with the value in +cur+
    def update_metric(cur)
      raise NotImplementedError
    end
  end
end
