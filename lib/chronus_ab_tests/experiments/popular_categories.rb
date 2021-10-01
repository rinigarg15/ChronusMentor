class Experiments::PopularCategories < ChronusAbExperiment

  module Alternatives
    CONTROL = 'Preference Categories Not Shown'
    ALTERNATIVE_B = 'Preference Categories Shown'

    GA_EVENT_LABEL_ID_MAPPING = {
      CONTROL => 1,
      ALTERNATIVE_B => 2      
    }
  end

  class << self
    def title
      "Preference Categories"
    end

    def description
      "Showing/not showing preference categories in self matched programs"
    end

    def experiment_config
      { 
        alternatives: [Alternatives::CONTROL, Alternatives::ALTERNATIVE_B]
      }
    end

    def enabled?
      true
    end

    def control_alternative
      Alternatives::CONTROL
    end

    def is_experiment_applicable_for?(program_or_org, user)
      program_or_org.is_a?(Program) && user.can_view_preferece_based_mentor_lists?
    end
  end

  def show_preference_categories?(show_preference_categories=false)
    show_preference_categories || (running? && alternative == Alternatives::ALTERNATIVE_B)
  end

  def event_label_id_for_ga
    Alternatives::GA_EVENT_LABEL_ID_MAPPING[alternative]
  end
end