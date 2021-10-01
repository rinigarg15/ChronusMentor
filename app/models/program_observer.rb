class ProgramObserver < ActiveRecord::Observer
  def after_create(program)
    return if program.disable_program_observer

    organization = program.organization
    organization.reload_programs_count

    program.populate_default_customized_terms
    program.create_default_roles
    program.create_notification_setting! unless program.created_for_sales_demo
    program.create_additional_roles_and_permissions unless program.created_using_solution_pack?
    program.create_recent_activity
    program.create_organization_admins_sub_program_admins
    program.create_program_languages
    create_default_role_questions(program) unless program.created_using_solution_pack?
    Program.delay.create_default_resource_publications(program.id) unless program.created_using_solution_pack? && !organization.standalone?
    # To Avoid The Failure of Creation of Program Using A CSV
    # Then the Program is created using Profile Questions
    organization.populate_default_customized_terms if program.skip_organization_validation
    Program.create_default_admin_views_and_its_dependencies(program.id)
    update_mentor_request_permissions(program)
    program.make_subscription_changes
    Program.delay.create_calendar_setting_for_program(program.id)
    program.create_default_mentoring_model!
    program.create_default_group_closure_columns! unless program.created_using_solution_pack?
    Program.delay.create_default_match_setting!(program.id)
    Program.delay.create_default_group_report_view_colums!(program.id)
    Program.delay.create_demographic_report_view_colums!(program.id)
    Organization.delay.clone_program_asset!(organization.id, program.id) if organization.program_asset.present? && !organization.standalone?

    if program.project_based?
      Feature.handle_specific_feature_dependency(program)
      update_project_request_permissions(program)
      handle_group_proposal_permissions(program) unless program.created_using_solution_pack?
    end

    Program.delay.create_default_program_management_report(program.id)
    if (program.surveys.of_meeting_feedback_type.empty? && !program.created_using_solution_pack?)
      Program.delay.create_default_meeting_feedback_surveys(program.id)
    end
    Program.delay.create_default_group_view(program.id)
    program.create_default_feedback_rating_questions
    program.disable_selected_mails_for_new_program_by_default
    program.build_mentor_request_instruction.save!
    Program.delay.populate_default_static_content_for_globalization(program.id)
    handle_program_match_report_settings(program)
  end

  def after_update(program)
    if program.saved_change_to_engagement_type? && program.project_based?
      Feature.handle_specific_feature_dependency(program)
      update_project_request_permissions(program)
    end

    handle_organization_changes(program)
    handle_program_match_report_settings(program) if program.saved_change_to_engagement_type? || program.saved_change_to_mentor_request_style?
  end

  # We call handle_destroy from target_deletion script to run the callbacks.
  # Please add any new changes in program.handle_destroy to maintain integrity.
  def after_destroy(program)
    program.handle_destroy
  end

  def before_validation(program)
    program.set_default_program_options
  end

  def before_save(program)
    if program.inactivity_tracking_period.nil? && !program.inactivity_tracking_period_was.nil?
      program.auto_terminate_reason_id = nil
    end
  end

  def after_save(program)
    if program.saved_change_to_mentor_request_style?
      update_mentor_request_permissions(program)
    end
  end

  private

  def handle_program_match_report_settings(program)
    return unless program.can_have_match_report?
    program.create_default_match_report_admin_views
    program.create_default_match_report_section_settings
    program.create_default_match_config_discrepancy_cache
  end

  def handle_organization_changes(program)
    organization = program.organization
    organization.reload_programs_count
    organization.update_attributes!(name: program.name, description: program.description) if (program.saved_change_to_name? || program.saved_change_to_description?) && organization.standalone?
  end

  def create_default_role_questions(program)
    program = Program.find(program.id)
    organization = program.organization
    default_mentor_role_questions = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_mentor_role_questions.yml")).result)["role_questions"]
    default_mentee_role_questions = YAML::load(ERB.new(IO.read("#{Rails.root.to_s}/config/default_mentee_role_questions.yml")).result)["role_questions"]
    org_questions_by_text = organization.profile_questions_with_email_and_name.group_by(&:question_text)
    {
      RoleConstants::MENTOR_NAME => default_mentor_role_questions,
      RoleConstants::STUDENT_NAME => default_mentee_role_questions
    }.each do |role_name, default_role_questions|
      default_role_questions.each do |ment_role_question|
        q_text = ment_role_question.delete('question_text')
        q_type = ment_role_question.delete('question_type')
        privacy_settings = ment_role_question.delete('privacy_settings')
        prof_q = org_questions_by_text[q_text]
        if prof_q.present?
          prof_q = q_type.present? ? prof_q.find{|ques| ques.question_type == q_type} : prof_q.first
          role = program.get_role(role_name)
          new_role_q = prof_q.role_questions.build(ment_role_question)
          new_role_q.role = role
          Array(privacy_settings).each do |privacy_setting|
            role_id = program.get_role(privacy_setting['role']).id if privacy_setting['setting_type'] == RoleQuestionPrivacySetting::SettingType::ROLE
            new_role_q.privacy_settings.build(role_id: role_id, setting_type: privacy_setting['setting_type'])
          end
          new_role_q.save!
        end
      end
    end
  end

  def update_mentor_request_permissions(program)
    program.roles.each do |role|
      RoleConstants::MENTOR_REQUEST_PERMISSIONS.each do |permission_name|
        if program.matching_by_admin_alone?
          role.remove_permission(permission_name)
        else
          default_role_permissions = RoleConstants::DEFAULT_ROLE_PERMISSIONS[role.name]
          role.add_permission(permission_name) if default_role_permissions.present? && default_role_permissions.include?(permission_name)
        end
      end
    end
  end

  def update_project_request_permissions(program)
    program.roles.each do |role|
      Array(RoleConstants::PROJECT_REQUEST_PERMISSIONS[role.name]).each do |permission_name|
        # Not handling remove_permission because changing the engagement_type(project_based)
        # is a one time configuration and cannot be changed later.
        role.add_permission(permission_name)
      end
    end
  end

  def handle_group_proposal_permissions(program)
    program.roles.for_mentoring.each do |role|
      role.add_permission(RolePermission::CREATE_PROJECT_WITHOUT_APPROVAL)
    end
  end
end
