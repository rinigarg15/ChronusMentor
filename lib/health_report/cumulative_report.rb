module HealthReport
  class CumulativeReport
    def self.cumulative_metric(*metric_names)
      # Returns the average threshold of all the metrics.
      define_method :average_threshold do
        thresholds = []
        metric_names.each do |metric_name|
          object = self.send(metric_name)
          metrics = object.is_a?(Hash) ? object.values : [object] 
          metrics.each do |metric|
            thresholds << metric.normalized_threshold unless metric.no_data?
          end
        end

        thresholds.compact!
        thresholds.average
      end

      # Returns the cumulative value of this metric
      define_method :cumulative_value do
        values = []
        metric_names.each do |metric_name|
          object = self.send(metric_name)
          metrics = object.is_a?(Hash) ? object.values : [object] 
          metrics.each do |metric|
            values << metric.value unless metric.no_data?
          end
        end

        effective_metric = PercentMetric.new(average_threshold)

        if values.empty?
          # No data
          effective_metric.update_metric(nil)
        else
          total_value = (values.sum / values.size.to_f)
          effective_metric.update_metric(total_value)
        end

        return effective_metric
      end
    end
  end
end
