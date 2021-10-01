# == Schema Information
#
# Table name: program_ab_tests
#
#  id         :integer          not null, primary key
#  test       :string(255)
#  program_id :integer
#  enabled    :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ProgramAbTest < ActiveRecord::Base

  belongs_to_program_or_organization

  module Experiment
    # EXAMPLE = "uiejudez" # "rand(36**8).to_s(36)
    SIGNUP_WIZARD = "hwbhh365"
    GUIDANCE_POPUP = "oqzu0ddk"
    MOBILE_APP_LOGIN_WORKFLOW = "6t65fsod"
    POPULAR_CATEGORIES = "kmm21wsb"
  end

  EXPERIMENT_DEFINITIONS = {
    # Experiment::EXAMPLE => Experiments::Example
    Experiment::SIGNUP_WIZARD => Experiments::SignupWizard,
    Experiment::GUIDANCE_POPUP => Experiments::GuidancePopup,
    Experiment::MOBILE_APP_LOGIN_WORKFLOW => Experiments::MobileAppLoginWorkflow,
    Experiment::POPULAR_CATEGORIES =>  Experiments::PopularCategories
  }

  def self.experiments
    [ 
      # Experiment::EXAMPLE
      Experiment::SIGNUP_WIZARD,
      Experiment::GUIDANCE_POPUP,
      Experiment::MOBILE_APP_LOGIN_WORKFLOW,
      Experiment::POPULAR_CATEGORIES   
    ]
  end

  def self.experiment(experiment_name)
    EXPERIMENT_DEFINITIONS[experiment_name]
  end

  def self.experiment_configs
    configs = {}
    EXPERIMENT_DEFINITIONS.each do |key, val|
      configs.merge!(val.split_config)
    end
    return configs
  end
end
