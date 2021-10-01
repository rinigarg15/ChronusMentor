class LinkedinImportController < ApplicationController
  include OpenAuthUtils::Extensions

  skip_before_action :set_time_zone, :configure_program_tabs, :configure_mobile_tabs,
                     :check_browser, :back_mark_pages,
                     :handle_pending_profile_or_unanswered_required_qs, :handle_terms_and_conditions_acceptance,
                     :login_required_in_program, :require_program

  allow exec: :linkedin_token_secret_present?
  allow exec: :program_present?, only: [:data]

  def login
    initialize_importer(get_access_token)

    if @linkedin_importer.is_access_token_valid?
      redirect_to linkedin_callback_path(existing: true)
    else
      initialize_auth_config
      callback_url = get_open_auth_callback_url
      redirect_to open_auth_authorization_redirect_url(callback_url, @auth_config, true)
    end
  end

  def callback
    initialize_auth_config

    if params[:existing].present?
      session[:linkedin_access_token] = get_access_token
    elsif params[:code].present? && is_open_auth_state_valid? && is_authorization_code_valid?
      session[:linkedin_access_token] = @auth_obj.linkedin_access_token
    end
    render layout: false
  end

  def data
    @section = Section.find(params[:section]) if params[:section]
    @is_from_membership_request = (params[:id] == "false")

    if @is_from_membership_request
      @roles = params[:membership_request_role_name].split(MembershipRequest::SEPARATOR)
      membership_request_member_id = params[:membership_request_member_id]
      @membership_request_member = @current_organization.members.find_by(id: membership_request_member_id)
      allow! exec: lambda { @membership_request_member == wob_member } if @membership_request_member.present? && wob_member.present?
    elsif params[:id]
      @user = @program.users.find(params[:id])
      @role = @user.role_names
      @member = @user.member
      allow! exec: lambda { @user == current_user }
    end
    fetch_and_import_profile
  end

  def callback_success
    render layout: false
  end

  private

  def linkedin_token_secret_present?
    @current_organization.linkedin_imports_allowed?
  end

  def program_present?
    @program =
      if !params[:program_id].present? || (params[:program_id] == "false")
        current_program
      else
        @current_organization.programs.find_by(id: params[:program_id])
      end
  end

  def get_access_token
    wob_member.try(:linkedin_access_token) || session[:linkedin_access_token]
  end

  def initialize_importer(access_token)
    @linkedin_importer = LinkedinImporter.new(access_token)
  end

  def initialize_auth_config
    @auth_config = @current_organization.linkedin_oauth(true)
  end

  def is_authorization_code_valid?
    @auth_obj = ProgramSpecificAuth.new(@auth_config, [params[:code], get_open_auth_callback_url])
    OpenAuth.authenticate?(@auth_obj, @auth_config.get_options) && @auth_obj.linkedin_access_token.present?
  end

  def fetch_and_import_profile
    initialize_importer(session[:linkedin_access_token])
    @linkedin_importer.import_data
    profile = @linkedin_importer.formatted_data

    if profile.blank?
      @error_flash = "flash_message.user_flash.import_profile_failure_v2".translate
    elsif profile[:experiences].empty?
      @error_flash = "flash_message.user_flash.import_empty_profile_v2".translate
    else
      @answer_map = build_answer_map(profile)
      unless @error_flash
        session[:linkedin_login_identifier] = profile[:id]
        set_member_linkedin_vars
        fetch_questions_to_be_filled
        track_ei
      end
    end
  end

  def build_answer_map(profile)
    importable_section_questions = @section.profile_questions.experience_questions
    importable_section_questions.inject({}) do |answer_map, question|
      answer = initialize_answer(question)
      build_answer(answer, profile)
      answer_map[question.id] = answer
      answer_map
    end
  end

  def initialize_answer(question)
    if @is_from_membership_request
      if @membership_request_member.present?
        @membership_request_member.answer_for(question) || @membership_request_member.profile_answers.build(profile_question: question)
      else
        membership_request = @program.membership_requests.new
        membership_request.profile_answers.build(profile_question: question)
      end
    else
      @member.answer_for(question) || @member.profile_answers.build(profile_question: question)
    end
  end

  def build_answer(answer, profile)
    if profile[:experiences].present?
      profile[:experiences].each do |data|
        profile_key_object = answer.experiences.build(data)
        profile_key_object.profile_answer = answer
      end
    end
  end

  def fetch_questions_to_be_filled
    @questions =
      if @is_from_membership_request
        @program.membership_questions_for(@roles)
      else
        @program.profile_questions_for(@role, default: false, user: current_user)
      end
    @questions.select! { |question| (question.section_id == @section.id) && question.linkedin_importable? }
  end

  def track_ei
    if (@member && (@member == wob_member)) || (@is_from_membership_request && wob_member)
      track_activity_for_ei(EngagementIndex::Activity::IMPORT_FROM_LINKEDIN)
    end
  end

  def set_member_linkedin_vars
    return unless logged_in_organization?

    handle_linkedin_login_identifier(wob_member)
    wob_member.linkedin_access_token = session[:linkedin_access_token]
    wob_member.save!
  end
end