class MembershipQuestionsController < ApplicationController
  include PreviewFormsCommon
  # Only super user can access these pages    
  
  before_action :handle_check_authorization_for_membership_questions, :except => [:preview]
  contextual_login_filters :only => [:preview]

  # All actions are allowed only for admin
  allow :user => :can_manage_membership_forms?, :except => [:preview]

  allow :exec => :check_for_membership_form_access, :only => [:preview]

  # Lists questions that can be edited checked/unchecked for roles.
  def index
    @sections = @current_organization.sections
    @membership_instruction = @current_program.membership_instruction.presence || @current_program.build_membership_instruction
    @membership_profile_questions = @current_program.role_questions_for(@current_program.roles_without_admin_role.collect(&:name), user: current_user).collect(&:profile_question).uniq.sort_by(&:position)
  end

  def preview
    set_programs_for_preview
    set_preview_filter_based_values
    # checking if preview program is authorized to access membership questions preview
    handle_check_authorization_for_membership_questions(@preview_program)
    @is_checkbox = @preview_program.show_and_allow_multiple_role_memberships?
    @membership_profile_questions = @preview_program.membership_questions_for(@filter_role)
    @sections = @membership_profile_questions.collect(&:section).uniq.sort_by(&:position)
    @membership_profile_questions = @membership_profile_questions.group_by(&:section_id)
    @grouped_role_questions = @preview_program.role_questions_for(@filter_role, fetch_all: true, include_privacy_settings: true).group_by(&:profile_question_id)
    @required_questions = @preview_program.role_questions_for(@filter_role).required.select([:required, :profile_question_id]).group_by(&:profile_question_id)
  end

  def update_role_questions
    role_question_to_update = @current_program.role_questions_for(params[:role]).where(:profile_question_id => params[:profile_question_id])[0]
    role_id = role_question_to_update.try(:role_id)
    if role_question_to_update.nil?
      r_q = @current_program.role_questions.new(:role_id => params[:role_id], :profile_question_id => params[:profile_question_id], :available_for => RoleQuestion::AVAILABLE_FOR::MEMBERSHIP_QUESTIONS)
      role_id ||= r_q.role_id
      r_q.save!
    elsif role_question_to_update.available_for == RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
      role_question_to_update.available_for = RoleQuestion::AVAILABLE_FOR::BOTH
      role_question_to_update.save!
    elsif role_question_to_update.available_for == RoleQuestion::AVAILABLE_FOR::BOTH
      role_question_to_update.available_for = RoleQuestion::AVAILABLE_FOR::PROFILE_QUESTIONS
      role_question_to_update.save!
    else
      role_question_to_update.destroy    
    end
    User.delay.es_reindex_for_profile_score(role_id)
  end

  private
  
  def handle_check_authorization_for_membership_questions(program = current_program)
    allow! exec: -> { check_authorization_for_membership_questions(program) }
  end


  def set_programs_for_preview
    @programs = super_console? ? @current_organization.programs : @current_organization.programs.allowing_membership_requests
    @programs = @programs.ordered
  end

  def set_preview_filter_based_values
    if params[:filter] && request.xhr?
      set_preview_filter_based_values_for_xhr
    else
      @filter_role = []
      @preview_program = params[:program_id].present? ? @programs.find_by(id: params[:program_id]) : (program_view? ? @current_program : @programs.first)
    end
  end

  def set_preview_filter_based_values_for_xhr
    @preview_program = @programs.find_by(id: params[:filter][:program])
    @filter_role_ids = params[:filter][:role]
    @filter_role = @preview_program ? @preview_program.roles.where(id: @filter_role_ids).pluck(:name) : []
  end

end
