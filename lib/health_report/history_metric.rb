module HealthReport
  # Metric that is represented as a value along with the change over last few.
  class HistoryMetric < AbstractMetric
    attr_accessor :value, :last_month

    def update_metric(value, last_month)
      self.value = value
      self.last_month = last_month
    end

    def last_change
      (self.value.zero? ? 0 : (self.last_month / self.value.to_f) * 100).round
    end
  end
end
