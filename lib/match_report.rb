class MatchReport

  attr_accessor :program, :current_status, :default_sections_data, :non_default_sections

  module SettingsSrc
    MATCH_REPORT = 'match_report'
  end

  module Sections
    CurrentStatus = "10"
    MentorDistribution = "20"
    MenteeActions = "30"

    DefaultSections = [CurrentStatus]
    NonDefaultSections = [MentorDistribution, MenteeActions]

    SectionClasses = {
      CurrentStatus => "MatchReport::CurrentStatus",
      MentorDistribution => "MatchReport::MentorDistribution",
      MenteeActions => "MatchReport::MenteeActions"
    }

    Partials = {
      CurrentStatus => "match_reports/current_status",
      MentorDistribution => {element_id: "mentor_distribution_info", partial: "match_reports/mentor_distribution/mentor_distribution"},
      MenteeActions => {element_id: "mentee_actions_info", partial: "match_reports/mentee_actions/mentee_actions"}
    }

    ContainerPartials = {
      MentorDistribution => "match_reports/mentor_distribution/mentor_distribution_container",
      MenteeActions => "match_reports/mentee_actions/mentee_actions_container"
    }
  end

  def initialize(program)
    self.program = program
    self.default_sections_data = self.get_section_data(Sections::DefaultSections, program)
    self.non_default_sections = self.get_non_default_sections_to_show(program)
  end

  def get_section_data(sections, program)
    sctions_data = []
    sections.each do |section|
      section_data = Hash.new
      section_data[section] = Sections::SectionClasses[section].constantize.new(program)
      sctions_data << section_data
    end
    sctions_data
  end

  def get_non_default_sections_to_show(program)
    sections_to_show = []
    Sections::NonDefaultSections.each do |section|
      sections_to_show << section if can_show_section?(section, program)
    end
    sections_to_show
  end

  private

  def can_show_section?(section, program)
    case section
    when Sections::MentorDistribution
      true
    when Sections::MenteeActions
      program.career_based_self_match_or_flash?
    end
  end

end