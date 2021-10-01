class Experiments::Example < ChronusAbExperiment

  module Alternatives
    CONTROL = 'Example Altertnative A'
    ALTERNATIVE_B = 'Example Altertnative B'
  end

  class << self
    def title
      "Example" # This will be the actual value being used by the split gem to identify the experiment
    end

    def description
      "This is an example to help developers implement more experiments" # Not having translated version as this is only for super users to see
    end

    def experiment_config
      { 
        :alternatives => [{:name => Alternatives::CONTROL, :percent => 60}, {:name => Alternatives::ALTERNATIVE_B, :percent => 40}],
        # can directly use [Alternatives::CONTROL, Alternatives::ALTERNATIVE_B] if both are of same percentage
        :metric => :example, # Needed only if a metric is needed
        :goals => ['red', 'green'] # Needed only if tracking goals
      }
    end

    def enabled?
      true # This is used to determine if a test is by default enabled for all programs/organizations by default or not
    end

    def control_alternative
      Alternatives::CONTROL # Control is the existing alternative
    end

    def is_experiment_applicable_for?(_prog_or_org, _user_or_member)
      true # Check Program/Org (or user/member) setting to determine even if the experiment if applicable
    end
  end

  # Below is a sample method for fetching text to be displayed for each alternative. 
  # Having methods like this and using them in the views instead of using if else logic in views
  # will help keep views logic simple and cleanup easy
  # def display_text_for_something
  #   case self.alternative
  #   when Alternatives::CONTROL
  #     "The original text"
  #   when Alternatives::ALTERNATIVE_B
  #     "New text we are testing"
  #   end
  # end

  # def source_params
  #   self.running? ? {src: AB_TESTS} : {}
  # end
end