module TranslationsService
  extend ActiveSupport::Concern
  mattr_accessor :program

  included do
    attr_accessor *translated_methods
  end

  module ClassMethods
    def translated_methods
      #Added Pluralized Mentorings term to maintaing consistency.
      [
        :_Mentee, :_Mentor, :_Employee, :_Admin,:_Article, :_Mentoring_Connection, :_Program, :_Resource, :_Meeting, :_Mentoring, :_Career_Development,
        :_Mentees, :_Mentors, :_Employees, :_Admins, :_Articles,:_Mentoring_Connections, :_Programs, :_Resources, :_Meetings, :_Mentorings, :_Career_Developments,
        :_mentee, :_mentor, :_employee, :_admin,:_article, :_mentoring_connection, :_program, :_resource, :_meeting, :_mentoring, :_career_development,
        :_mentees, :_mentors, :_employees, :_admins,:_articles, :_mentoring_connections, :_programs, :_resources, :_meetings, :_mentorings, :_career_developments,
        :_a_mentee, :_a_mentor, :_a_employee, :_a_admin, :_a_mentoring_connection, :_a_program, :_a_resource, :_a_article, :_a_meeting, :_a_mentoring, :_a_career_development,
        :_a_Mentee, :_a_Mentor, :_a_Employee, :_a_Admin, :_a_Mentoring_Connection, :_a_Program, :_a_Resource, :_a_Article, :_a_Meeting, :_a_Mentoring, :_a_Career_Development
      ]
    end
  end

  def set_terminology_helpers
    scope = TranslationsService.program
    return unless scope.present?
    TranslationsService::initialize_custom_terms(self, scope)
  end

  def self.initialize_custom_terms(base, scope, suffix = "")
    program_roles = scope.roles.includes(customized_term: :translations) if scope.is_a?(Program)

    # Program level administrator customized term is not intended to be used anywhere.
    [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME, RoleConstants::EMPLOYEE_NAME].each do |role_name|
      customized_role_term = program_roles.find { |role| role.name == role_name }.try(:customized_term) if scope.is_a?(Program)
      role_name = RoleConstants::ROLE_DISPLAY_NAME_MAPPING[role_name].present? ? RoleConstants::ROLE_DISPLAY_NAME_MAPPING[role_name] : role_name

      base.instance_variable_set("@_#{role_name.capitalize}#{suffix}", customized_role_term.try(:term) || role_name.humanize)
      base.instance_variable_set("@_#{role_name.capitalize}s#{suffix}", customized_role_term.try(:pluralized_term) || base.instance_variable_get("@_#{role_name.capitalize}#{suffix}").pluralize)
      base.instance_variable_set("@_a_#{role_name.capitalize}#{suffix}", customized_role_term.try(:articleized_term) || base.instance_variable_get("@_#{role_name.capitalize}#{suffix}").articleize)
      base.instance_variable_set("@_#{role_name}#{suffix}", customized_role_term.try(:term_downcase) || base.instance_variable_get("@_#{role_name.capitalize}#{suffix}").downcase)
      base.instance_variable_set("@_#{role_name}s#{suffix}", customized_role_term.try(:pluralized_term_downcase) || base.instance_variable_get("@_#{role_name}#{suffix}").pluralize)
      base.instance_variable_set("@_a_#{role_name}#{suffix}", customized_role_term.try(:articleized_term_downcase) || base.instance_variable_get("@_#{role_name}#{suffix}").articleize)
    end
    prog_customized_terms = scope.customized_terms.includes(:translations)
    org_customized_terms =
      if scope.is_a?(Program)
        scope.organization.customized_terms.includes(:translations)
      else
        prog_customized_terms
      end
    CustomizedTerm::TermType::ALL_NON_ROLE_TERMS.each do |term_type|
      customized_terms = CustomizedTerm::TermType::ORGANIZATION_LEVEL_TERMS.include?(term_type) ? org_customized_terms : prog_customized_terms
      customized_term = customized_terms.find { |term| term.term_type == term_type }
      base.instance_variable_set("@_#{term_type}#{suffix}", customized_term.term)
      base.instance_variable_set("@_#{term_type}s#{suffix}", customized_term.pluralized_term)
      base.instance_variable_set("@_a_#{term_type}#{suffix}", customized_term.articleized_term)
      base.instance_variable_set("@_#{term_type.downcase}#{suffix}", customized_term.term_downcase)
      base.instance_variable_set("@_#{term_type.downcase}s#{suffix}", customized_term.pluralized_term_downcase)
      base.instance_variable_set("@_a_#{term_type.downcase}#{suffix}", customized_term.articleized_term_downcase)
    end
  end
end