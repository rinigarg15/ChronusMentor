require_relative './../test_helper.rb'

class ProgramAbTestTest < ActiveSupport::TestCase
  def test_belongs_to_prog_or_org
    prog = programs(:albers)
    p_ab_test = prog.ab_tests.create(test: 'Something', enabled: false)
    assert_equal prog, p_ab_test.program

    org = programs(:org_primary)
    p_ab_test = org.ab_tests.create(test: 'Something', enabled: false)
    assert_equal org, p_ab_test.program
  end

  def test_experiments
    assert_equal [ProgramAbTest::Experiment::SIGNUP_WIZARD, ProgramAbTest::Experiment::GUIDANCE_POPUP, ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, ProgramAbTest::Experiment::POPULAR_CATEGORIES], ProgramAbTest.experiments
  end

  def test_experiment
    assert_equal Experiments::SignupWizard, ProgramAbTest.experiment(ProgramAbTest::Experiment::SIGNUP_WIZARD)
  end
end