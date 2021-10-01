module RoleConstants
	EMPLOYEE_NAME = 'employee'
	DEFAULT_CAREER_DEV_ROLE_NAMES = [ADMIN_NAME, EMPLOYEE_NAME]

  module Default
    EMPLOYEE = 100
  end
	DEFAULT_CAREER_DEV_ROLE_PERMISSIONS = {
		EMPLOYEE_NAME => %w(
			view_articles rate_answer ask_question view_questions follow_question answer_question view_ra
		),
		ADMIN_NAME => %w(manage_admins manage_announcements write_article view_articles manage_articles 
			view_audit_logs manage_forums manage_membership_forms approve_membership_request manage_custom_pages 
			invite_admins invite_employees create_program customize_program rate_answer manage_answers ask_question view_questions 
			follow_question answer_question manage_questions manage_profile_forms view_reports manage_surveys manage_themes access_themes 
			add_non_admin_profiles  update_profiles manage_user_states work_on_behalf manage_email_templates view_ra manage_translations view_employees
		)
	}

	DEFAULT_CAREER_DEV_ROLE_SETTINGS = {
		ADMIN_NAME => {:default => Default::ADMIN, :invitation => true, :administrative => true, :for_mentoring => false},
		EMPLOYEE_NAME => {:default => Default::EMPLOYEE, :invitation => true, :for_mentoring => false}
	}

	CAREER_DEV_PERMISSIONS = DEFAULT_CAREER_DEV_ROLE_PERMISSIONS.values.flatten.uniq
end