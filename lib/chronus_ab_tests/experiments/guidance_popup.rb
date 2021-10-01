class Experiments::GuidancePopup < ChronusAbExperiment

  module Alternatives
    CONTROL = 'Popup Not Shown'
    ALTERNATIVE_B = 'Popup Shown'

    GA_EVENT_LABEL_ID_MAPPING = {
      CONTROL => 1,
      ALTERNATIVE_B => 2      
    }
  end

  class << self
    def title
      "SMP Guidance Popup V2"
    end

    def description
      "Showing/not showing guidance popup after mentees publish their profiles in self matched programs"
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

    def is_experiment_applicable_for?(program, user)
      program.is_a?(Program) && program.self_match_and_not_pbe? && user.is_student? && user.can_view_mentors?
    end
  end

  def show_guidance_popup?(show_guidance_popup=false)
    show_guidance_popup || (running? && alternative == Alternatives::ALTERNATIVE_B)
  end

  def event_label_id_for_ga
    Alternatives::GA_EVENT_LABEL_ID_MAPPING[alternative]
  end
end