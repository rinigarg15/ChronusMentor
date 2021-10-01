require_relative './../../../../test_helper.rb'

class Experiments::ExampleTest < ActiveSupport::TestCase
  def test_title
    assert_equal 'Example', Experiments::Example.title
  end

  def test_description
    assert_equal "This is an example to help developers implement more experiments", Experiments::Example.description
  end

  def test_experiment_config
    config = Experiments::Example.experiment_config
    assert_equal [{name: Experiments::Example::Alternatives::CONTROL, percent: 60}, 
                  {name: Experiments::Example::Alternatives::ALTERNATIVE_B, percent: 40}], config[:alternatives]
    assert_equal :example, config[:metric]
    assert_equal ['red', 'green'], config[:goals]
  end

  def test_enabled
    assert Experiments::Example.enabled?
  end

  def test_control_alternative
    assert_equal Experiments::Example::Alternatives::CONTROL, Experiments::Example.control_alternative
  end

  def test_is_experiment_applicable_for
    assert Experiments::Example.is_experiment_applicable_for?('prog', 'user')
  end
end
