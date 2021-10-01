require_relative './../../../test_helper'

class HealthReport::CumulativeReportTest < ActiveSupport::TestCase
  class TestMetric < HealthReport::CumulativeReport
    attr_accessor :metric_1
    attr_accessor :metric_2
    attr_accessor :metric_3
    cumulative_metric :metric_1, :metric_2, :metric_3
  end
  
  def test_overall_metrics
    test_metric = TestMetric.new
    m1 = stubs(:metric_1)
    m1.expects(:normalized_threshold).at_least(0).returns(0.2)
    m1.expects(:value).at_least(0).returns(0.8)
    m1.expects(:no_data?).at_least(0).returns(false)
    
    m2 = stubs(:metric_2)
    m2.expects(:normalized_threshold).at_least(0).returns(0.6)
    m2.expects(:value).at_least(0).returns(0.33)
    m2.expects(:no_data?).at_least(0).returns(false)
    
    m3 = stubs(:metric_3)
    m3.expects(:normalized_threshold).at_least(0).returns(0.12)
    m3.expects(:value).at_least(0).returns(0.7)
    m3.expects(:no_data?).at_least(0).returns(false)
    
    test_metric.expects(:metric_1).at_least(0).returns(m1)
    test_metric.expects(:metric_2).at_least(0).returns(m2)
    test_metric.expects(:metric_3).at_least(0).returns(m3)
    assert_equal((0.8 + 0.33 + 0.7) / 3.0, test_metric.cumulative_value.value)
  end
end
