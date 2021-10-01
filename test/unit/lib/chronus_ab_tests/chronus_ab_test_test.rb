require_relative './../../../test_helper.rb'

class ChronusAbTestTest < ActiveSupport::TestCase
  include ChronusAbTest

  def test_chronus_ab_test_for_enabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Program.any_instance.stubs(:ab_test_enabled?).returns(true)
    experiment = chronus_ab_test('example')
    assert_equal 'Some text', experiment.alternative
    assert experiment.running?

    experiment2 = chronus_ab_test('example', false)
    assert_equal Experiments::Example.control_alternative, experiment2.alternative
    assert_false experiment2.running?

    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).returns(false)
    experiment3 = chronus_ab_test('example')
    assert_equal Experiments::Example.control_alternative, experiment3.alternative
    assert_false experiment3.running?
  end

  def test_chronus_ab_test_for_disabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Program.any_instance.stubs(:ab_test_enabled?).returns(false)
    experiment = chronus_ab_test('example')
    assert_equal Experiments::Example.control_alternative, experiment.alternative
    assert_false experiment.running?
  end

  def test_finished_chronus_ab_test_enabled
    self.stubs(:participating_in_ab_test?).with('example').returns(true)
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Program.any_instance.stubs(:ab_test_enabled?).returns(true)
    assert_equal Experiments::Example.title, finished_chronus_ab_test('example')
    assert_nil finished_chronus_ab_test('example', false)
    assert_equal 'red', finished_chronus_ab_test('example', true, 'red')[Experiments::Example.title]

    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).returns(false)
    assert_nil finished_chronus_ab_test('example')

    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).returns(true)
    self.stubs(:participating_in_ab_test?).with('example').returns(false)
    assert_nil finished_chronus_ab_test('example')
  end

  def test_finished_chronus_ab_test_disabled
    self.stubs(:participating_in_ab_test?).with('example').returns(true)
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Program.any_instance.stubs(:ab_test_enabled?).returns(false)
    assert_nil finished_chronus_ab_test('example')
    assert_nil finished_chronus_ab_test('example', true, 'red')
  end

  def test_chronus_ab_counter_inc_for_enabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Program.any_instance.stubs(:ab_test_enabled?).returns(true)
    assert_equal ["Step Name", Experiments::Example.title, 'Some text'], chronus_ab_counter_inc("Step Name", 'example')
    assert_nil chronus_ab_counter_inc("Step Name", 'example', false)

    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).returns(false)
    assert_nil chronus_ab_counter_inc("Step Name", 'example')
  end

  def test_chronus_ab_counter_inc_for_disabled
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Program.any_instance.stubs(:ab_test_enabled?).returns(false)
    assert_nil chronus_ab_counter_inc("Step Name", 'example')
  end

  def test_alternative_choosen_in_ab_test
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    ChronusAbTestSplitUser.any_instance.stubs(:alternative_choosen).with(Experiments::Example.title).returns("something")
    assert_equal "something", alternative_choosen_in_ab_test('example')
  end

  def test_participating_in_ab_test?
    self.stubs(:alternative_choosen_in_ab_test).with("experiment_name").returns(true)
    assert participating_in_ab_test?("experiment_name")

    self.stubs(:alternative_choosen_in_ab_test).with("experiment_name").returns(false)
    assert_false participating_in_ab_test?("experiment_name")
  end

  def test_chronus_ab_test_only_use_cookie
    self.stubs(:chronus_ab_test_only_use_cookie_wrapper).returns("something")
    self.stubs(:chronus_ab_test).with("experiment_name", "conduct_experiment", 'no_program_or_organization').returns("nothing")
    assert_equal "something", chronus_ab_test_only_use_cookie("experiment_name", "conduct_experiment", 'no_program_or_organization')
  end

  def test_finished_chronus_ab_test_only_use_cookie
    self.stubs(:chronus_ab_test_only_use_cookie_wrapper).returns("something")
    self.stubs(:finished_chronus_ab_test).with("experiment_name", "conduct_experiment", nil, 'no_program_or_organization').returns("nothing")
    assert_equal "something", finished_chronus_ab_test_only_use_cookie("experiment_name", "conduct_experiment", 'no_program_or_organization')
  end

  def test_chronus_ab_test_only_use_cookie_wrapper
    assert_false ChronusAbExperiment.only_use_cookie
    chronus_ab_test_only_use_cookie_wrapper do
      assert ChronusAbExperiment.only_use_cookie
    end
    assert_false ChronusAbExperiment.only_use_cookie

    assert_equal "something", chronus_ab_test_only_use_cookie_wrapper{Proc.new{ return "something" }.call}
  end

  def test_should_conduct_ab_experiment
    ChronusAbExperiment.only_use_cookie = true
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).never
    programs(:albers).stubs(:ab_test_enabled?).with('example').never
    assert_false should_conduct_ab_experiment?('example', false)

    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).returns(false)
    programs(:albers).stubs(:ab_test_enabled?).with('example').never
    assert_false should_conduct_ab_experiment?('example', true)

    ChronusAbExperiment.only_use_cookie = false
    Experiments::Example.stubs(:is_experiment_applicable_for?).with(programs(:albers), users(:f_admin)).returns(true)
    programs(:albers).stubs(:ab_test_enabled?).with('example').returns(false)
    assert_false should_conduct_ab_experiment?('example', true)

    programs(:albers).stubs(:ab_test_enabled?).with('example').returns(true)
    assert should_conduct_ab_experiment?('example', true)
  end

  def test_chronus_ab_test_get_experiment
    ProgramAbTest.stubs(:experiment).with('example').returns(Experiments::Example)
    self.stubs(:should_conduct_ab_experiment?).with('example', 'conduct_experiment', 'no_program_or_organization').returns(false)
    self.stubs(:alternative_choosen_in_ab_test).with('example').never
    Experiments::Example.stubs(:new).with(nil).returns('No Alternative')
    assert_equal 'No Alternative', chronus_ab_test_get_experiment('example', 'conduct_experiment', 'no_program_or_organization')

    self.stubs(:should_conduct_ab_experiment?).with('example', 'conduct_experiment', 'no_program_or_organization').returns(true)
    self.stubs(:alternative_choosen_in_ab_test).with('example').returns('something')
    Experiments::Example.stubs(:new).with('something').returns('Some Alternative')
    assert_equal 'Some Alternative', chronus_ab_test_get_experiment('example', 'conduct_experiment', 'no_program_or_organization')    
  end

  private

  def current_program_or_organization
    programs(:albers)
  end

  def current_user_or_wob_member
    users(:f_admin)
  end

  def ab_test(experiment)
    'Some text'
  end

  def ab_finished(experiment_params)
    experiment_params
  end

  def ab_counter_inc(step_name, experiment_name, alternative)
    [step_name, experiment_name, alternative]
  end
end