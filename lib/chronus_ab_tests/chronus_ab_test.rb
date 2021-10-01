module ChronusAbTest
  def chronus_ab_test(experiment_name, conduct_experiment=true, no_program_or_organization=false)
    experiment_klass = ProgramAbTest.experiment(experiment_name)
    alternative = should_conduct_ab_experiment?(experiment_name, conduct_experiment, no_program_or_organization) ? ab_test(experiment_klass.title) : nil
    return experiment_klass.new(alternative)
  end

  def chronus_ab_test_only_use_cookie(experiment_name, conduct_experiment=true, no_program_or_organization=false)
    chronus_ab_test_only_use_cookie_wrapper do
      chronus_ab_test(experiment_name, conduct_experiment, no_program_or_organization)
    end
  end

  def finished_chronus_ab_test(experiment_name, conduct_experiment=true, goal=nil, no_program_or_organization=false)
    experiment_klass = ProgramAbTest.experiment(experiment_name)
    finish_params = goal.present? ? {experiment_klass.title => goal} : experiment_klass.title
    ab_finished(finish_params) if should_conduct_ab_experiment?(experiment_name, conduct_experiment, no_program_or_organization) && participating_in_ab_test?(experiment_name)
  end

  def finished_chronus_ab_test_only_use_cookie(experiment_name, conduct_experiment=true, no_program_or_organization=false)
    chronus_ab_test_only_use_cookie_wrapper do
      finished_chronus_ab_test(experiment_name, conduct_experiment, nil, no_program_or_organization)
    end
  end

  def chronus_ab_counter_inc(step_name, experiment_name, conduct_experiment=true)
    experiment = chronus_ab_test(experiment_name, conduct_experiment)
    ab_counter_inc(step_name, experiment.class.title, experiment.alternative) if experiment.running?
  end

  def alternative_choosen_in_ab_test(experiment_name)
    experiment_klass = ProgramAbTest.experiment(experiment_name)
    ChronusAbTestSplitUser.new(self).alternative_choosen(experiment_klass.title)
  end

  def participating_in_ab_test?(experiment_name)
    alternative_choosen_in_ab_test(experiment_name).present?
  end

  def chronus_ab_test_get_experiment(experiment_name, conduct_experiment=true, no_program_or_organization=false)
    experiment_klass = ProgramAbTest.experiment(experiment_name)
    alternative = should_conduct_ab_experiment?(experiment_name, conduct_experiment, no_program_or_organization) ? alternative_choosen_in_ab_test(experiment_name) : nil
    return experiment_klass.new(alternative)
  end

  def chronus_ab_test_only_use_cookie_wrapper
    ChronusAbExperiment.only_use_cookie = true
    yield
    ensure
      ChronusAbExperiment.only_use_cookie = false
  end

  def should_conduct_ab_experiment?(experiment_name, conduct_experiment=true, no_program_or_organization=false)
    experiment_klass = ProgramAbTest.experiment(experiment_name)
    perform_experiment = conduct_experiment && experiment_klass.is_experiment_applicable_for?(current_program_or_organization, current_user_or_wob_member) 
    perform_experiment &&= current_program_or_organization.ab_test_enabled?(experiment_name) unless no_program_or_organization
    perform_experiment
  end
end