require_relative './../../../test_helper.rb'

class ChronusAbExperimentTest < ActiveSupport::TestCase
  def test_split_config
    config = {"ChronusAbExperiment" => {}}
    assert_equal config, ChronusAbExperiment.split_config
  end

  def test_initilize
    e1 = ChronusAbExperiment.new
    assert_nil e1.alternative
    assert_false e1.running?
    e2 = ChronusAbExperiment.new('apple')
    assert_equal 'apple', e2.alternative
    assert e2.running?
  end

  def test_running
    exp = ChronusAbExperiment.new
    exp.stubs(:running).returns(true)
    assert exp.running?

    exp.stubs(:running).returns(false)
    assert_false exp.running?
  end
end
