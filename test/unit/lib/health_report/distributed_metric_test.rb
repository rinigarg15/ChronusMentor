require_relative './../../../test_helper'

class HealthReport::DistributedMetricTest < ActiveSupport::TestCase
  def test_metric
    metric = HealthReport::DistributedMetric.new(['Coffee', 'Tea', 'Milk'])
    assert_equal 3, metric.components.size
    assert_equal ['Coffee', 'Tea', 'Milk'], metric.components.collect(&:name)
    compare_distribution({'Coffee' => 0.0, 'Tea' => 0.0, 'Milk' => 0.0}, metric.distribution)
    
    assert_raise HealthReport::DistributedMetric::InvalidDistributionError do
      metric.update_metric({'Coffee' => 0.6, 'Tea' => 0.30, 'Milk' => 0.2})
    end

    assert_raise HealthReport::DistributedMetric::InvalidDistributionError do
      metric.update_metric({'Coffee' => 0.9, 'Tea' => 0.30, 'Milk' => 0.2})
    end

    # Unspecified components must be filled as 0.0
    metric.update_metric({'Coffee' => 0.2, 'Tea' => 0.8})
    compare_distribution({'Coffee' => 0.2, 'Tea' => 0.8, 'Milk' => 0.0}, metric.distribution)

    metric.update_metric({'Coffee' => 0.3, 'Tea' => 0.6, 'Milk' => 0.1})
    compare_distribution({'Coffee' => 0.3, 'Tea' => 0.6, 'Milk' => 0.1}, metric.distribution)
  end
  
  private
  
  # Compares the hash distribution and OrderedHash distribution
  def compare_distribution(hash_dist, ordered_dist)
    assert_equal hash_dist, ordered_dist.to_hash
  end
end
