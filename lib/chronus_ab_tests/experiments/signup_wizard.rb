class Experiments::SignupWizard < ChronusAbExperiment

  include ActionView::Helpers::TagHelper
  include ActionView::Context

  module Alternatives
    CONTROL = 'Wizard not shown'
    ALTERNATIVE_B = 'Wizard shown'
  end

  class << self
    def title
      "Signup Wizard"
    end

    def description
      "Experiment to test if showing a wizard during signup increases the completion rate"
    end

    def experiment_config
      { 
        :alternatives => [Alternatives::CONTROL, Alternatives::ALTERNATIVE_B]
      }
    end

    def enabled?
      false
    end

    def control_alternative
      Alternatives::CONTROL
    end

    def is_experiment_applicable_for?(_prog_or_org, _user_or_member)
      true
    end
  end

  def render_wizard(sections, section_type, section_index, profile_user, current_program)
    return unless self.running? && self.alternative == Alternatives::ALTERNATIVE_B

    first_section_content, title_content = first_section_content_and_title(section_type)

    profile_section_content, profile_section_title = profile_section_content_and_title(sections, section_type, section_index)
    title_content += profile_section_title

    last_section_content, last_section_title = last_section_content_and_title(profile_user, current_program, section_type, sections)
    title_content += last_section_title

    render_wizard_content(first_section_content, profile_section_content, last_section_content, title_content)
  end

  def last_section_content_and_title(profile_user, current_program, section_type, sections)
    mentoring_settings_enabled = profile_user.can_set_availability? && (current_program.allow_mentor_update_maxlimit? || current_program.calendar_enabled?)
    mentoring_term = current_program.term_for(CustomizedTerm::TermType::MENTORING_CONNECTION_TERM).term
    last_section_status = (section_type == MembersController::EditSection::MENTORING_SETTINGS) ? "active" : ""
    last_section_content = "".html_safe
    title_content = "".html_safe

    if mentoring_settings_enabled
      last_section_content = content_tag(:span, '', class: "wizard-bar #{last_section_status}") + 
                             content_tag(:span, content_tag(:span, sections.size + 2, class: "wizard-label"), class: "wizard-circle #{last_section_status}")
      title_content = content_tag(:div, "feature.user.label.mentoring_settings".translate(:Mentoring => mentoring_term), class: "wizard-title #{last_section_status}")
    end
    return last_section_content, title_content
  end

  private

  def render_wizard_content(first_section_content, profile_section_content, last_section_content, title_content)
    content_tag(:div, class: "row-fluid") do
      content_tag(:div, class: "cui-signup-wizard") do
        first_section_content +    
        profile_section_content +
        last_section_content +
        content_tag(:div, title_content)
      end
    end
  end

  def signup_wizard_section(index, section_status_class)
    content_tag(:span, '', class: "wizard-bar#{section_status_class}") +
    content_tag(:span, class: "wizard-circle#{section_status_class}") do
      content_tag(:span, index + 2, class: "wizard-label")
    end
  end

  def first_section_content_and_title(section_type)
    first_section_status = (section_type == MembersController::EditSection::GENERAL) ? "active" : "done"
    first_section_content = content_tag(:span, content_tag(:span, 1, class: "wizard-label"), class: "wizard-circle #{first_section_status}")
    first_section_title = content_tag(:div, "feature.user.label.summary".translate, class: "wizard-title #{first_section_status}")
    return first_section_content, first_section_title
  end

  def profile_section_content_and_title(sections, section_type, section_index)
    profile_section_content = "".html_safe
    title_content = "".html_safe
    sections.each_with_index do |section, index|
      section_status_class = ((section_type == MembersController::EditSection::MENTORING_SETTINGS) || (index < section_index)) ? " done" : (index == section_index) ? " active" : ""
      profile_section_content += signup_wizard_section(index, section_status_class)
      title_content += content_tag(:div, section.title, class: "wizard-title#{section_status_class}")
    end
    return profile_section_content, title_content
  end
end