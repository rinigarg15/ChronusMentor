module RoleConstants
  # Permissions that require showing the 'Manage' page.
  MANAGEMENT_PERMISSIONS = %w(
    customize_program manage_custom_pages manage_themes manage_announcements
    manage_connections view_reports manage_admins manage_surveys
    view_audit_logs manage_profile_forms
    manage_membership_forms add_non_admin_profiles manage_student_feedbacks manage_email_templates
    manage_translations)

  MENTOR_NAME = 'mentor'
  MENTORS_NAME = 'mentors'
  STUDENT_NAME = 'student'
  STUDENTS_NAME = 'students'
  ADMIN_NAME = 'admin'
  ADMINS_NAME = 'admins'
  BOARD_OF_ADVISOR_NAME = "board_of_advisor"
  BOARD_OF_ADVISORS_NAME = "board_of_advisors"
  TEACHER_NAME = 'teacher'
  TEACHERS_NAME = 'teachers'

  ROLE_DISPLAY_NAME_MAPPING = {
    STUDENT_NAME => "mentee"
  }

  AUTO_APPROVAL_ROLE_MAPPING = {
    MENTOR_NAME => STUDENT_NAME,
    STUDENT_NAME => MENTOR_NAME
  }

  MENTORING_ROLES = [MENTOR_NAME, STUDENT_NAME]

  module Default
    ADMIN = 0
    MENTOR = 1
    STUDENT = 2

    def self.all
      constants.collect{|c| const_get(c)}
    end
  end

  module JoinSetting
    APPLY_TO_JOIN = "apply_to_join"
    ELIGIBILITY_RULES = "eligibility_rules"
    JOIN_DIRECTLY = 'join_directly'
    JOIN_DIRECTLY_ONLY_WITH_SSO = 'join_directly_only_with_sso'
    MEMBERSHIP_REQUEST = 'membership_request'
    INVITATION = 'invitation'
  end

  module SlotConfig
    OPTIONAL = 1
    REQUIRED = 2

    def self.all
      [OPTIONAL, REQUIRED]
    end
  end

  module InviteRolePermission
    MENTOR_CAN_INVITE = 'mentor_invite'
    MENTEE_CAN_INVITE = 'student_invite'

    ## Add the new roles (and permission name) which need invitation permissions below
    module RoleName
      MENTOR_NAME = 'mentor'
      STUDENT_NAME = 'student'
      ADMIN_NAME = 'admin'
      USER_NAME = 'user'
      TEACHER_NAME = "teacher"
    end

    Permission = {
      RoleName::MENTOR_NAME => 'invite_mentors',
      RoleName::STUDENT_NAME => 'invite_students',
      RoleName::ADMIN_NAME => 'invite_admins',
      RoleName::USER_NAME => 'invite_users',
      RoleName::TEACHER_NAME => 'invite_teachers'
    }
  end

  MENTOR_REQUEST_PERMISSIONS = %w(send_mentor_request manage_mentor_requests)
  PROJECT_REQUEST_PERMISSIONS = {
    RoleConstants::STUDENT_NAME => %w(send_project_request view_find_new_projects),
    RoleConstants::MENTOR_NAME => %w(send_project_request view_find_new_projects),
    RoleConstants::ADMIN_NAME => %w(manage_project_requests)
  }

  DEFAULT_ROLE_NAMES = [ADMIN_NAME, MENTOR_NAME, STUDENT_NAME]

  DEFAULT_ROLE_SETTINGS = {
    MENTOR_NAME => {:default => Default::MENTOR, :invitation => true, :membership_request => true, for_mentoring: true},
    STUDENT_NAME => {:default => Default::STUDENT, :invitation => true, :membership_request => true, for_mentoring: true},
    ADMIN_NAME => {:default => Default::ADMIN, :invitation => true, :administrative => true, for_mentoring: false},
    BOARD_OF_ADVISOR_NAME => {:administrative => true, for_mentoring: false}
  }

  DEFAULT_ROLE_PERMISSIONS = {
    MENTOR_NAME => %w(
write_article   view_articles   invite_mentors
rate_answer     ask_question    view_questions
follow_question answer_question view_mentors view_students
set_availability   view_ra),

    STUDENT_NAME => %w(
view_articles      invite_students      rate_answer
ask_question       view_questions       follow_question
answer_question    view_mentors view_students
send_mentor_request view_mentoring_calendar  view_ra set_meeting_preference ignore_and_mark_favorite),

    ADMIN_NAME => %w(manage_admins manage_announcements write_article view_articles manage_articles
 view_audit_logs manage_forums manage_connections  manage_match_configs
 manage_membership_forms approve_membership_request manage_mentor_requests manage_custom_pages invite_students
 invite_mentors invite_admins create_program customize_program rate_answer  manage_answers ask_question view_questions
 follow_question answer_question manage_questions manage_profile_forms view_reports manage_surveys manage_themes access_themes
 manage_student_feedbacks  add_non_admin_profiles  update_profiles view_mentors view_students manage_user_states
 manage_mentoring_tips work_on_behalf manage_email_templates view_ra view_coach_rating manage_translations),

    BOARD_OF_ADVISOR_NAME => %w(view_reports)
  }

  UNASSIGNED_PERMISSIONS = %w(offer_mentoring become_mentor become_student invite_users invite_teachers view_users view_teachers become_user propose_groups reactivate_groups create_project_without_approval) + PROJECT_REQUEST_PERMISSIONS.values.flatten.uniq

  DEFAULT_PERMISSIONS = DEFAULT_ROLE_PERMISSIONS.values.flatten.uniq + UNASSIGNED_PERMISSIONS

  DEFAULT_CUSTOMIZED_TERMS_MAPPING = {
    MENTOR_NAME => "Mentor",
    STUDENT_NAME => "Mentee",
    ADMIN_NAME => "Administrator"
  }

  FAQ_PAGE = {
    RoleConstants::MENTOR_NAME => "For Mentors",
    RoleConstants::STUDENT_NAME => "For Mentees"
  }

  def self.program_roles_mapping(program_or_organization, options = {})
    role_mapping = {}
    (options[:roles] || get_roles(program_or_organization, options).includes(customized_term: :translations)).each do |role|
      custom_role_term =
        if role.admin?
          program_or_organization.get_organization.admin_custom_term
        else
          role.customized_term
        end
      get_role_mapping(program_or_organization, custom_role_term, {role_mapping: role_mapping, role: role}, options)
    end
    role_mapping
  end

  # Maps the each role name in <i>role_names</i> to organization specific role name
  # (mentor_name and mentee_name) and returns an Array of those role names.
  def self.to_program_role_names(program, role_names)
    role_mapping = RoleConstants.program_roles_mapping(program)
    role_names.collect { |name| role_mapping[name] || name }
  end

  # Returns a string formed by joining the names of the <i>roles</i>.
  #
  #   ['mentor'] => 'Mentor'
  #   ['admin','student'] => 'Administrator and Mentee'
  #   ['mentor','admin','student'] => 'Mentor, Administrator and Student'
  #

  def self.human_role_string(role_names, opts = {})
    program_roles = opts[:program].roles.includes(customized_term: :translations) if opts[:program].present?
    str = role_names.each.collect do |role_name|
      # TODO : CareerDev - Hardcoded Role. Check translations
      if opts[:program].present?
        custom_term =
          if role_name == RoleConstants::ADMIN_NAME
            opts[:program].get_organization.admin_custom_term
          else
            program_roles.find { |role| role.name == role_name }.try(:customized_term)
          end
      end
      if custom_term.present?
        term = if opts[:pluralize]
          opts[:no_capitalize] ? custom_term.pluralized_term_downcase : custom_term.pluralized_term
        else
          opts[:no_capitalize] ? custom_term.term_downcase : custom_term.term
        end
      else
        term = role_name.humanize
        term = term.pluralize if opts[:pluralize]
        term = UnicodeUtils.downcase(term) if opts[:no_capitalize]
      end
      term
    end
    str = str.to_sentence
    str = str.articleize if opts[:articleize] && !opts[:pluralize]
    str = "display_string.as".translate + " " + str if opts[:as]
    return str
  end

  def self.get_roles(program_or_organization, options = {})
    if program_or_organization.is_a?(Program)
      program_or_organization.roles 
    else
      all_roles = program_or_organization.all_roles
      options[:administrative].nil? ? all_roles : all_roles.where(administrative: options[:administrative])
    end
  end

  def self.get_role_mapping(program_or_organization, custom_role_term, additional_params, options = {})
    role_mapping, role = [additional_params[:role_mapping], additional_params[:role]]
    mapped_name = get_mapped_name(custom_role_term, options)
    program_or_organization.is_a?(Program) ? (role_mapping[role.name] = mapped_name) : ((role_mapping[role.name] ||= []) << mapped_name)
  end

  def self.get_mapped_name(custom_role_term, options = {})
    if options[:pluralize]
      options[:no_capitalize] ? custom_role_term.pluralized_term_downcase : custom_role_term.pluralized_term
    else
      options[:no_capitalize] ? custom_role_term.term_downcase : custom_role_term.term
    end
  end
end
