class MembershipRequestsController < ApplicationController
  include Report::MetricsUtils
  include Experiments::MobileAppLoginWorkflow::FinishMobileAppExperiment

  LIST_PER_PAGE = 20
  DETAILED_PER_PAGE = 10
  SEPARATOR = ","
  NOT_ELIGIBLE_ROLE = 2

  # Skiping program required for new and create as logged in user should be able to create from organization level via enrollment page

  skip_before_action :login_required_in_program, only: [:new, :create, :edit, :update, :signup_options, :apply, :signup_instructions, :resend_signup_mail]
  skip_before_action :require_program, only: [:new, :create, :edit, :update]
  skip_before_action :handle_terms_and_conditions_acceptance, only: [:new, :create]

  before_action :set_bulk_dj_priority, only: [:bulk_update, :new_bulk_action]
  before_action :set_index_filter_hash_and_tab, only: [:index, :select_all_ids, :export]
  before_action :get_list_type, only: [:index, :destroy]
  before_action :prepare_filter_params, only: [:export]
  before_action :set_program_and_membership_request, only: [:edit, :update]
  before_action :handle_membership_request_edit, only: [:edit, :update]

  allow user: :can_approve_membership_request?, only: [:index, :destroy, :bulk_update, :new_bulk_action, :select_all_ids, :export]

  def index
    @metric = get_source_metric(current_program, params[:metric_id])
    @src_path = params[:src]
    @filters_to_apply, @tabs_data, @filters_count, filtered_membership_requests = MembershipRequestService.get_filtered_membership_requests(@current_program, @filter_hash, @list_type, @tab)
    @membership_questions_for_roles, @membership_filterable_questions = get_membership_questions_for_roles, get_filterable_questions 
    get_sorted_requests!(filtered_membership_requests)
    page = @filter_hash[:page].to_i != 0 ? @filter_hash[:page].to_i : 1
    @items_per_page = @filter_hash[:items_per_page] || get_default_per_page(@list_type)
    respond_to do |format|
      format.any(:html, :js) do
        @membership_requests = @membership_requests.includes([profile_answers: [:educations, :publications, :experiences, :profile_question, :answer_choices]]).paginate(page: page, per_page: @items_per_page).to_a
      end
    end
  end

  def signup_options
    if params[:roles].present?
      allow! exec: Proc.new { allowed_role?(params[:roles], @current_program, true) }
      @roles = @current_program.find_roles(params[:roles])
      @auth_configs = Role.get_signup_options(@current_program, @roles)
      # session[:signup_roles] is also set in 2 other instances
      # using the before_action :store_signup_roles_in_session
      session[:signup_roles] = { @current_program.root => params[:roles] }
      initialize_login_sections(@auth_configs)
    else
      head :ok
    end
  end

  def signup_instructions
    @only_login = true
    @skip_rounded_white_box_for_content = true
    finish_mobile_app_login_experiment(cookies[:uniq_token]) if is_mobile_app?
  end

  def resend_signup_mail
    if params[:email].present? && params[:roles].present?
      @is_valid = send_mail_for_applying_using_chronus_auth(from_signup_instructions_mail: true)
    end
  end

  def apply
    if params[:email].present? && params[:roles].present?
      if ValidatesEmailFormatOf::validate_email_format(params[:email], check_mx: false).present?
        flash[:error] = "flash_message.password_flash.invalid_email".translate
        do_redirect new_membership_request_path and return
      end
      if simple_captcha_valid?
        send_mail_for_applying_using_chronus_auth
        do_redirect signup_instructions_membership_requests_path(roles: params[:roles], email: params[:email].strip)
      else
        flash[:error] = "flash_message.admin_message.captcha_fail".translate
        do_redirect new_membership_request_path
      end
    end
  end

  def new
    @is_self_view = true
    @only_login = true
    @from_enrollment = params[:from_enrollment].present? ? params[:from_enrollment].to_boolean : false
    membership_request_params = params || {}
    @program = membership_request_params[:program].present? ? @current_organization.programs.find_by(id: membership_request_params[:program]) : @current_program
    allow! exec: Proc.new { @program.present? }

    @password = Password.find_by(reset_code: params[:signup_code]) if params[:signup_code].present?
    @email = logged_in_organization? ? wob_member.email : @password.try(:email_id)
    @member = wob_member || @current_organization.members.find_by(email: @email)
    @roles = Array(membership_request_params[:roles])
    current_role_names, pending_role_names, @can_apply_role_names = get_role_info(@member || @email)
    roles_flash = get_flash_on_roles(current_role_names, pending_role_names, @can_apply_role_names, @program)
    @is_checkbox = @program.show_and_allow_multiple_role_memberships?
    @membership_instruction_content = @program.membership_instruction.try(:content)
    @display_terms_and_conditions = !@member.present? || @member.terms_and_conditions_accepted.nil?

    redirect_path = handle_redirects_on_invalid_cases(membership_request_params, roles_flash)
    if @no_redirect
      return
    elsif redirect_path.present?
      do_redirect(redirect_path) and return
    end

    if @roles.present? && @member.present?
      role_objects = @program.find_roles(@roles)
      if new_user_authenticated_externally? && session_import_data.present?
        unless @member.update_answers(@current_organization.profile_questions.includes(question_choices: :translations), session_import_data["ProfileAnswer"], nil, nil, nil, from_import: true)
          notify_airbrake(StandardError.new("Profile answers update failed: Import data from SSO - #{session_import_data['ProfileAnswer']}"))
        end
      end
      set_eligibility_options(@member, role_objects)
      if !request.xhr? && !@member.can_modify_eligibility_details?(role_objects)
        if !@eligible_to_join
          flash.now[:error] = get_eligibility_message
          redirect_to program_root_path(root: @program.root) and return
        elsif @eligible_to_join_directly && (logged_in_organization? || new_user_authenticated_externally?)
          @roles = get_eligible_roles
          new_membership_request_params = {roles: @roles, first_name: @member.first_name, last_name: @member.last_name, email: @member.email, joined_directly: true, accepted_as: @roles.join(MembershipRequest::SEPARATOR), status: MembershipRequest::Status::ACCEPTED}
          @membership_request = MembershipRequest.create_from_params(@program, new_membership_request_params, (@member.valid? ? @member : nil))
          @new_user = @membership_request.create_user_from_accepted_request if @membership_request.valid?
          if @new_user.present? && @new_user.valid?
            redirect_valid_new_user and return
          end
        end
      end
    end

    # Logged in, membership requests new page, after selecting the roles
    # Enrollment page, popup after the roles are selected
    # When an unlogged-in user returns from mail after apply-for page
    if @roles.present? && (logged_in_organization? || new_user_authenticated_externally? || @password.present?)
      allow! exec: Proc.new { allowed_role?(@roles, @program) }
      flash.now[:notice] = "flash_message.membership.to_join_complete_form_v1_html".translate(role_names: RoleConstants.human_role_string(@roles, program: @program))
      if session_import_data.present? || params[:profile_answers].present?
        profile_answers_hash = (session_import_data.try(:[], "ProfileAnswer") || {}).merge(params[:profile_answers].try(:permit!) || {}).with_indifferent_access
        initialize_answer_map(ProfileAnswer::PRIORITY::IMPORTED, profile_answers_hash, logged_in_organization? ? @member : nil)
      end
      if !logged_in_organization? && session_import_data.present?
        @member_attributes_from_sso = session_import_data["Member"].present? && session_import_data["Member"].symbolize_keys.pick(:first_name, :last_name, :email)
        @email ||= session_import_data_email
      end
      initialize_membership_request(true, @member_attributes_from_sso || {})
      if @empty_form && logged_in_organization? && !@display_terms_and_conditions && !request.xhr?
        membership_request_params = {first_name: @membership_request.first_name, last_name: @membership_request.last_name, email: @email, roles: @membership_request.role_names, program_id: @membership_request.program.id}
        membership_request_params.merge!(first_name: @member.first_name, last_name: @member.last_name) if @member.present?
        handle_membership_request_creation(membership_request_params)
      end
    # Logged in, membership requests new page, select the roles
    elsif logged_in_organization? || new_user_authenticated_externally?
      @section_id_questions_map = @current_organization.default_questions.group_by(&:section_id)
      @sections = @current_organization.sections.default_section
      membership_request_params =
        if new_user_authenticated_externally? && session_import_data.present? && session_import_data["Member"].present?
          session_import_data["Member"].symbolize_keys.pick(:first_name, :last_name, :email)
        else
          { email: @email, first_name: @member.try(:first_name), last_name: @member.try(:last_name) }
        end
      @membership_request = @program.membership_requests.build(membership_request_params)
      flash.now[:notice] ||= roles_flash if roles_flash.present?
    # Apply-for: When an unlogged-in user clicks on 'Join Now'
    else
      @roles = @roles.present? ? @program.find_roles(@roles) : @program.roles.allowing_join_now
      flash.now[:notice] = "flash_message.membership.membership_required_to_add_as_favorite".translate(mentor: _mentor) if params[:src] == "favorite"
      render action: "apply_for"
    end
  end

  def create
    @is_self_view = true
    membership_request_params = params[:membership_request] || {}
    @program = membership_request_params[:program_id].present? ? @current_organization.programs.find(membership_request_params[:program_id]) : @current_program
    allow! exec: Proc.new { @program.present? && membership_request_params.present? }
    @password = Password.find_by(reset_code: params[:signup_code]) if params[:signup_code].present?
    @email = logged_in_organization? ? wob_member.email : (@password.try(:email_id) || session_import_data_email || membership_request_params[:email])
    @member = wob_member || @current_organization.members.find_by(email: @email)
    @roles = Array(params[:roles] || membership_request_params[:roles])
    allow! exec: Proc.new { @roles.present? && allowed_role?(@roles, @program) }
    current_role_names, pending_role_names, @can_apply_role_names = get_role_info(@member || @email)
    roles_flash = get_flash_on_roles(current_role_names, pending_role_names, @can_apply_role_names, @program)

    redirect_path = handle_redirects_on_invalid_cases(membership_request_params, roles_flash)
    redirect_to redirect_path and return if redirect_path.present?
    membership_request_params = membership_request_params.slice(:roles, :first_name, :last_name).merge!(email: @email)
    membership_request_params.merge!(first_name: @member.first_name, last_name: @member.last_name) if @member.present?
    handle_membership_request_creation(membership_request_params, check_accepted_signup_terms?)
  rescue VirusError
    flash[:error] = "flash_message.membership.virus_present".translate
    options = { signup_code: @password.try(:reset_code), roles: @roles } if !logged_in_organization?
    redirect_to new_membership_request_path(options.merge(root: @program.root))
  end

  def edit
    initialize_questions_and_answers_map(@is_admin_editing)
  end

  def update
    membership_request_params = params[:membership_request]
    profile_questions_to_update = @program.membership_questions_for(@roles, include_admin_only_editable: @is_admin_editing, user: current_user)
    begin
      ActiveRecord::Base.transaction do
        @member.update_attributes(membership_request_permitted_params(membership_request_params, :update))
        @membership_request.update_attributes(membership_request_permitted_params(membership_request_params, :update))

        # The attr_accessor user_or_membership_request in profile answer is used to find the required questions and raise validation errors when they are not filled. But, when an admin edits the membership questions, we do not enforce required questions restrictions. Hence if the current user is admin, we do not pass the @membership_request to the following method (@member.update_answers)
        unless @member.update_answers(profile_questions_to_update, params[:profile_answers].try(:to_unsafe_h), (@is_admin_editing ? nil : @membership_request), false, @is_admin_editing, params)
          @profile_answers_updation_error = true
        end
        handle_email_validation_error
        handle_exception_on_membership_request_save
      end
    rescue => ex
      @updation_failure = true
    end
    if @updation_failure
      @log_error ? logger.error("--- #{ex.message} ---") : notify_airbrake(ex)
      initialize_questions_and_answers_map(@is_admin_editing)
      @invalid_answer_details = @member.get_invalid_profile_answer_details
      render :edit
    else
      flash[:notice] = "flash_message.membership_request_flash.update_success".translate
      redirect_to get_redirect_path_for_edit_or_update
    end
  end

  def new_bulk_action
    @membership_request = MembershipRequest.new
    @membership_requests = @current_program.membership_requests.not_joined_directly.where(id: params[:membership_request_ids])
    @status = params[:status].try(:to_i)
    render partial: "membership_requests/bulk_actions_popup.html"
  end

  def bulk_update
    membership_request_ids = params[:membership_request_ids].split(SEPARATOR)
    membership_requests = @current_program.membership_requests.where(id: membership_request_ids)
    status = params[:membership_request][:status].to_i if params[:membership_request].present?
    if status.blank?
      membership_requests.destroy_all
    else
      pending_membership_requests = membership_requests.pending
      if status == MembershipRequest::Status::ACCEPTED
        accepted_as = params[:membership_request][:accepted_as].try(:join, SEPARATOR)
        pending_membership_requests = pending_membership_requests.includes(:roles) unless accepted_as.present?
      end
      request_size = pending_membership_requests.size
      pending_membership_requests.find_each do |membership_request|
        accepted_as = membership_request.role_names_str if status == MembershipRequest::Status::ACCEPTED && (request_size > 1 || accepted_as.nil?)
        membership_request.update_attributes!(membership_request_permitted_params(params[:membership_request], :bulk_update).merge({accepted_as: accepted_as, admin: current_user}))
      end
    end

    @success_flash = bulk_flash_message(status, membership_requests, membership_request_ids.size)
    flash[:notice] = @success_flash
    respond_to do |format|
      format.html { redirect_to_back_mark_or_default(membership_requests_path) }
      format.js
    end
  end

  def select_all_ids
    membership_requests = MembershipRequestService.get_filtered_membership_requests(@current_program, @filter_hash, nil, @tab, true)
    render json: { membership_request_ids: membership_requests.pluck(:id).map(&:to_s), member_ids: membership_requests.pluck(:member_id) }
  end

  def export
    @membership_requests = if params[:membership_request_ids].present?
      @current_program.membership_requests.not_joined_directly.where(id: params[:membership_request_ids].split(MembershipRequestsController::SEPARATOR))
    else
      MembershipRequestService.get_filtered_membership_requests(@current_program, @filter_hash, nil, @tab, true)
    end

    if @membership_requests.empty?
      export_handle_no_requests
    else
      respond_to do |format|
        # Making js request for pdf format as the pdf is emailed
        format.js do
          export_requests(@tab, @filters_to_apply[:sort_scope], :pdf)
        end

        format.csv do
          export_requests(@tab, @filters_to_apply[:sort_scope], :csv)
        end
      end
    end
  end

  private

  def check_accepted_signup_terms?
    if !@member.present? || @member.terms_and_conditions_accepted.nil?
      accepted_signup_terms?
    else
      true
    end
  end

  def membership_request_permitted_params(params, action)
    if params.is_a?(ActionController::Parameters)
      params.permit(MembershipRequest::MASS_UPDATE_ATTRIBUTES[action])
    else
      params
    end
  end

  def handle_membership_request_edit
    if @membership_request.blank? || @membership_request.answered?
      flash[:error] = "flash_message.membership_request_flash.not_found".translate if @membership_request.blank?
      redirect_to get_redirect_path_for_edit_or_update
    else
      @is_self_view = @membership_request.member == wob_member
      allow! exec: Proc.new { @is_admin_editing || @is_self_view }

      @roles = @membership_request.role_names
      @is_edit_action = true
      @member = @membership_request.member
    end
  end

  def set_program_and_membership_request
    @program = @current_program
    @membership_request = @program.membership_requests.find_by(id: params[:id])
    @is_admin_editing = current_user.try(&:can_approve_membership_request?)
    @is_admin_view = true if @is_admin_editing
  end

  def get_redirect_path_for_edit_or_update
    @is_admin_editing ? membership_requests_path : new_membership_request_path
  end

  def handle_membership_request_creation(membership_request_params, accepted_signup_terms = true)
    begin
      ActiveRecord::Base.transaction do
        unless @member.present?
          @member = @current_organization.members.new(membership_request_permitted_params(membership_request_params, :member_creation))
          @member.state = Member::Status::DORMANT
          is_new_member = true
        end
        unless logged_in_organization? || @member.can_signin?
          @member.password = params[:password]
          @member.password_confirmation = params[:password_confirmation]
        end
        assign_external_login_params(@member)
        @member.time_zone = params[:time_zone] if @member.time_zone.blank?
        if @member.save
          @member.accept_terms_and_conditions! if accepted_signup_terms
          Language.set_for_member(@member, current_locale)
        end

        @membership_questions = @program.membership_questions_for(@roles)
        # Creating a dummy membership request instance for profile answers validation
        membership_request_for_answers = @program.membership_requests.new
        membership_request_for_answers.role_names = @roles
        unless @member.update_answers(@membership_questions, params[:profile_answers].try(:to_unsafe_h), membership_request_for_answers, is_new_member, false, params)
          @profile_answers_updation_error = true
        end

        role_objects = @program.find_roles(@roles)
        set_eligibility_options(@member, role_objects)
        @roles = get_eligible_roles
        if !@suspended_user && (!@program.membership_request_only_roles_present?(@roles) || @eligible_to_join_directly)
          membership_request_params.merge!(joined_directly: true, accepted_as: @roles.join(MembershipRequest::SEPARATOR), status: MembershipRequest::Status::ACCEPTED)
        end
        @membership_request = MembershipRequest.create_from_params(@program, membership_request_permitted_params(membership_request_params, :membership_request_creation).merge(roles: membership_request_params[:roles]), (@member.valid? ? @member : nil), params)
        @new_user = @membership_request.create_user_from_accepted_request if @membership_request.valid? && (@membership_request.joined_directly? || @eligible_to_join_directly) && !@suspended_user
        handle_exception_on_membership_request_save(true)
      end
    rescue => e
      @creation_failure = true
      if @log_error
        logger.error "--- #{e.message} ---"
      else
        notify_airbrake(e)
      end
    end

    unless @creation_failure
      @password.destroy if @password.present?
      session[:signup_roles] = nil

      MembershipRequest.delay.trigger_manager_notification(@membership_request.id)
      Matching.perform_users_delta_index_and_refresh_later(@member.user_ids, @program)

      if @new_user.present? && @new_user.valid?
       redirect_valid_new_user
      else
        if new_user_authenticated_externally?
          logout_killing_session!
          self.current_member = @member
        end
        flash[:notice] = "flash_message.membership.created_v1".translate(program: _program, administrators: _admins)
        redirect_to program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
      end
    else
      @email = logged_in_organization? ? wob_member.email : @password.try(:email_id)
      @invalid_password = !@member.valid? && @member.errors[:password].present?
      @invalid_answer_details = @member.get_invalid_profile_answer_details
      initialize_answer_map(ProfileAnswer::PRIORITY::IMPORTED, nil, @member)
      @member = wob_member || @current_organization.members.find_by(email: @email)
      @is_checkbox = @program.show_and_allow_multiple_role_memberships?
      initialize_membership_request(false)
      flash.now[:error] = get_eligibility_message if !@eligible_to_join && @valid_member
      render action: "new"
    end
  end

  def send_mail_for_applying_using_chronus_auth(options = {})
    role_names = params[:roles].split(COMMON_SEPARATOR)
    member = @current_organization.members.find_by(email: params[:email].strip)
    user = member.present? && member.user_in_program(current_program)
    allow! exec: Proc.new { role_names.present? && allowed_role?(role_names, current_program) }

    if member.present?
      if member.suspended?
        ChronusMailer.complete_signup_suspended_member_notification(current_program, member).deliver_now
        return true
      else
        roles = current_program.find_roles(role_names)
        set_eligibility_options(member, roles)
        if !@eligible_to_join && !member.can_modify_eligibility_details?(roles)
          ChronusMailer.not_eligible_to_join_notification(current_program, member, role_names).deliver_now
          return true
        elsif member.crypted_password.present?
          if options[:from_signup_instructions_mail]
            reset_password_object = member.passwords.last
            # Password object is destroyed after using the invite code and signing in
            if reset_password_object.blank?
              flash[:error] = "flash_message.user_flash.reusing_invitation".translate(program: _program, click_here: view_context.link_to("display_string.click_here".translate, login_path))
              return false
            end
          else
            reset_password_object = member.passwords.create!
          end
          include_signup_params_in_login_url = !user.present? || user.suspended? || (role_names - user.role_names).present?
          ChronusMailer.complete_signup_existing_member_notification(current_program, member, role_names, reset_password_object.reset_code, include_signup_params_in_login_url).deliver_now
          return true
        end
      end
    end

    # This is equivalent to member.blank? || !member.crypted_password.present?
    signup_code_object = options[:from_signup_instructions_mail] ? Password.where(email_id: params[:email]).last : Password.create!(email_id: params[:email])
    ChronusMailer.complete_signup_new_member_notification(current_program, params[:email], role_names, signup_code_object.reset_code, { locale: I18n.locale } ).deliver_now
    return true
  end

  def allowed_role?(role_names, program, ignore_sso = false)
    allowed_roles = program.roles.allowing_join_now
    can_join = role_names.present? && (role_names - allowed_roles.pluck(:name)).empty?
    roles_only_with_sso = allowed_roles.allowing_join_directly_only_with_sso
    can_join_only_with_sso = role_names.present? && (role_names - roles_only_with_sso.pluck(:name)).empty?
    can_join && (ignore_sso || logged_in_organization? || new_user_external_auth_config.try(:custom?) || !can_join_only_with_sso)
  end

  def get_role_info(member_or_email = nil)
    member = member_or_email.is_a?(Member) && member_or_email
    email = member.present? ? member.email : member_or_email
    member_id = member.present? ? member.id : nil

    @user = member.present? && member.user_in_program(@program)
    @suspended_user = @user.try(:suspended?)

    current_role_names = (@user.blank? || @suspended_user) ? [] : @user.role_names
    allowed_role_names = @program.roles.allowing_join_now.pluck(:name)
    allowed_role_names -= @program.roles.allowing_join_directly_only_with_sso.pluck(:name) if new_user_external_auth_config.try(:default?)
    pending_role_names = member_or_email.present? ? set_and_get_pending_membership_requests(email, member_id).collect(&:role_names).flatten.uniq : []
    can_apply_role_names = allowed_role_names - (current_role_names + pending_role_names)

    return current_role_names, pending_role_names, can_apply_role_names
  end

  def get_flash_on_roles(current_role_names, pending_role_names, can_apply_role_names, program)
    messages = []
    messages << "flash_message.membership.membership_required_to_add_as_favorite".translate(mentor: _mentor) if params[:src] == "favorite"
    messages << "flash_message.membership.suspended_user_v1_html".translate(program: program.name) if @suspended_user && pending_role_names.empty?
    messages << "flash_message.membership.current_roles_present_html".translate(role_name: RoleConstants.human_role_string(current_role_names, program: program), prog_name: program.name) if current_role_names.present?
    if pending_role_names.present?
      messages << "flash_message.membership.request_pending_roles_v1_html".translate(role_name: RoleConstants.human_role_string(pending_role_names, program: program), program: program.name)
      messages << "feature.contact_admin.content.contact_for_questions_html".translate(contact_admin: get_contact_admin_path(program))
    end
    messages << "flash_message.membership.to_join_complete_form_v1_html".translate(role_names: RoleConstants.human_role_string(can_apply_role_names, program: program)) if can_apply_role_names.present?
    messages.join(" ").html_safe
  end

  def handle_redirects_on_invalid_cases(membership_request_params, roles_flash = "")
    email_from_param_or_password = @password.try(:email_id) || membership_request_params[:email]
    if params[:signup_code].present? && @password.nil?
      flash[:error] = "flash_message.membership.invalid_signup_code".translate
      program_root_path(root: @program.root)

    # Force login if member can sign-in
    elsif !logged_in_organization? && @member.try(:can_signin?)
      if new_user_authenticated_externally?
        logout_killing_session!
        login_link = view_context.link_to("display_string.login".translate, login_path)
        flash[:error] = "flash_message.membership.existing_user_different_uid_html".translate(email: @member.email, program: _program, login_link: login_link)
      else
        session[:signup_code] = { @program.root => { code: @password.try(:reset_code), roles: @roles } }
      end
      handle_member_who_can_signin_during_signup(@member, prevent_redirect: true, hide_flash: flash[:error].present?)

    # If currently logged in and the emails do not match, force logout
    elsif email_from_param_or_password.present? && logged_in_organization? && wob_member.email.downcase != email_from_param_or_password.downcase
      logout_killing_session!
      new_membership_request_path(signup_code: @password.try(:reset_code), roles: @roles)

    # No roles can be joined through membership form
    elsif !@program.allow_join_now?
      flash[:notice] = "flash_message.membership.to_join_v2_html".translate(program: _program, click_here: get_contact_admin_path(program, label: "display_string.click_here".translate), administrators: _admins)
      program_root_path(root: @program.root)

    # No roles can be joined as already been enrolled to or pending membership requests exist
    elsif !@can_apply_role_names.present? || (@roles.present? && (@roles & @can_apply_role_names).empty?)
      if @member.try(:suspended?)
        flash[:notice] = "flash_message.membership.to_join_v2_html".translate(program: _program, click_here: get_contact_admin_path(program, label: "display_string.click_here".translate), administrators: _admins)
        program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
      elsif roles_flash.present?
        flash[:notice] ||= roles_flash
        if @can_apply_role_names.present?
          new_membership_request_path(signup_code: @password.try(:reset_code))
        elsif @pending_membership_requests.blank?
          program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
        else
          @no_redirect = true
          return
        end
      else
        program_root_path(root: @program.root, src: MembershipRequest::Source::MEMBERSHIP_REQUEST_PAGE)
      end

    # Applying for multiple roles when only one at a time is permitted
    elsif @roles.size > 1 && !@program.show_and_allow_multiple_role_memberships?
      flash[:notice] = "flash_message.membership.apply_for_only_one".translate
      new_membership_request_path

    # Subset of roles in params can only be applied for, just do a redirect to same action
    elsif @roles.present? && (@roles - @can_apply_role_names).any?
      flash[:notice] ||= roles_flash if roles_flash.present?
      common_role_names = @roles & @can_apply_role_names
      logged_in_organization? ? new_membership_request_path(root: @program.root) : new_membership_request_path(root: @program.root, signup_code: @password.try(:reset_code), roles: common_role_names)
    end
  end

  def initialize_membership_request(new_record = true, member_attrs_from_sso = {})
    initialize_questions_and_answers_map
    @questions_to_answer = @section_id_questions_map.values.flatten - @current_organization.default_questions
    attrs = { email: @email, first_name: @member.try(:first_name), last_name: @member.try(:last_name) }.merge!(member_attrs_from_sso)
    @membership_request = @program.membership_requests.build(attrs) if new_record || @membership_request.blank?
    @membership_request.role_names = @roles
    @empty_form = wob_member.present? && @membership_request.role_names.present? && @questions_to_answer.blank?
  end

  def initialize_questions_and_answers_map(include_admin_only_editable = false)
    options = include_admin_only_editable ? { include_admin_only_editable: true, user: current_user } : {}
    @required_question_ids = @program.role_questions_for(@roles).required.pluck(:profile_question_id)
    ordered_profile_questions_to_display = @program.membership_questions_for(@roles, options)
    @sections = ordered_profile_questions_to_display.collect(&:section).uniq.sort_by(&:position)
    @section_id_questions_map = ordered_profile_questions_to_display.group_by(&:section_id)
    initialize_answer_map(ProfileAnswer::PRIORITY::EXISTING, nil, @member)
  end

  def set_index_filter_hash_and_tab
    @tab = params[:tab] || MembershipRequest::FilterStatus::PENDING
    if params[:action].to_sym == :index && params[:view_id].present? && @prog_inv_view = @current_program.abstract_views.find(params[:view_id])
      alert = @prog_inv_view.alerts.find_by(id: params[:alert_id])
      @filter_hash = alert.present? ? FilterUtils.process_filter_hash_for_alert(@prog_inv_view, @prog_inv_view.filter_params_hash, alert) : @prog_inv_view.filter_params_hash
      @filter_hash.merge!(params.permit(:page, :items_per_page))
    else
      @filter_hash = params
    end
  end

  def get_list_type
    hash = @filter_hash || params
    session[:list_type] = hash[:list_type].present? ? hash[:list_type].to_i : (session[:list_type].present? ? session[:list_type] : MembershipRequest::ListStyle::DETAILED)
    @list_type = session[:list_type]
  end

  def prepare_filter_params
    @filters_to_apply = MembershipRequestService.filters_to_apply(@filter_hash, @list_type, @current_program)
  end

  def export_handle_no_requests
    flash[:error] = "flash_message.membership.no_data_to_export".translate
    redirect_to membership_requests_path unless request.xhr?
  end

  def export_requests(tab, sort_scope, format)
    case format
    when :csv
      CSVStreamService.new(response).setup!(MembershipRequest.export_file_name(format), self) do |stream|
        MembershipRequest.export_to_stream(stream, current_user, @membership_requests.map(&:id), tab, sort_scope)
      end
    when :pdf
      MembershipRequest.delay(queue: DjQueues::HIGH_PRIORITY).generate_and_email_report(current_user, @membership_requests.map(&:id),
        tab, sort_scope, format, JobLog.generate_uuid, I18n.locale)
      @success_message = "flash_message.membership.export_successful".translate(file_format: format.to_s.upcase)
    end
  end

  def get_default_per_page(list_type)
    (list_type == MembershipRequest::ListStyle::LIST) ? LIST_PER_PAGE : DETAILED_PER_PAGE
  end

  def bulk_flash_message(status, membership_requests, membership_requests_size)
    if status == MembershipRequest::Status::ACCEPTED
      "flash_message.membership.bulk_accepted_html".translate(count: membership_requests.size, click_here: "<a href='#{member_path(membership_requests.first.member)}'>#{'display_string.Click_here'.translate}</a>".html_safe)
    elsif status == MembershipRequest::Status::REJECTED
      "flash_message.membership.bulk_rejected".translate(count: membership_requests.size, name: membership_requests.first.name)
    else
      "flash_message.membership.bulk_deleted".translate(count: membership_requests_size)
    end
  end

  def get_sorted_requests!(filtered_membership_requests)
    if @filters_to_apply[:sort_field] =~ /^question-(\d+)$/
      question_id = $1.to_i
      @membership_requests = MembershipRequest.sorted_by_answer(filtered_membership_requests, @current_organization, question_id, @filters_to_apply[:sort_order])
    else
      @membership_requests = filtered_membership_requests.send(*@filters_to_apply[:sort_scope])
    end
  end

  def initialize_answer_map(priority, answer_value_hash, member)
    @answer_map ||= {}
    if answer_value_hash.present?
      id_question_map = @current_organization.profile_questions_with_email_and_name.includes(question_choices: :translations).index_by(&:id)
      answer_value_hash.each do |profile_question_id, answer_value|
        profile_answer = build_profile_answer(id_question_map[profile_question_id.to_i], answer_value, member)
        set_priority_and_add_to_answer_map(profile_answer, priority)
      end
    elsif member.present?
      member.profile_answers.each do |profile_answer|
        set_priority_and_add_to_answer_map(profile_answer, priority)
      end
    end
  end

  def build_profile_answer(profile_question, answer_value, member)
    profile_answer = member.try(:answer_for, profile_question) || profile_question.profile_answers.new(ref_obj: member)
    if profile_question.education?
      profile_answer.handle_existing_education_answers(answer_value[:existing_education_attributes], false)
      profile_answer.build_new_education_answers(answer_value[:new_education_attributes], false)
    elsif profile_question.experience?
      profile_answer.handle_existing_experience_answers(answer_value[:existing_experience_attributes], false)
      profile_answer.build_new_experience_answers(answer_value[:new_experience_attributes], false)
    elsif profile_question.publication?
      profile_answer.handle_existing_publication_answers(answer_value[:existing_publication_attributes], false)
      profile_answer.build_new_publication_answers(answer_value[:new_publication_attributes], false)
    elsif profile_question.manager?
      profile_answer.handle_existing_manager_answers(answer_value[:existing_manager_attributes], false)
      profile_answer.build_new_manager_answers(answer_value[:new_manager_attributes], false)
    elsif profile_question.file_type?
      profile_answer.assign_file_name_and_code(answer_value, params["question_#{profile_question.id}_code"])
    else
      profile_answer.answer_value = {answer_text: answer_value, question: profile_question, from_import: true}
    end
    profile_answer
  end

  def set_priority_and_add_to_answer_map(profile_answer, priority)
    profile_answer.priority = priority
    exisiting_profile_answer = @answer_map[profile_answer.profile_question_id.to_s]
    if exisiting_profile_answer.blank? || exisiting_profile_answer.priority <= priority
      @answer_map.merge!(profile_answer.profile_question_id.to_s => profile_answer)
    end
  end

  def set_eligibility_options(member, role_objects)
    if member.present?
      @eligible_to_join_roles = []
      @eligible_to_join_directly_roles = []
      @not_eligible_to_join_roles = []
      @not_eligible_to_join_directly_roles = []
      role_objects.each do |role_object|
        eligible_to_join, eligible_to_join_directly = member.is_eligible_to_join?([role_object])
        if eligible_to_join
          @eligible_to_join_roles << role_object
        else
          @not_eligible_to_join_roles << role_object
        end
        if eligible_to_join_directly
          @eligible_to_join_directly_roles << role_object
        else
          @not_eligible_to_join_directly_roles << role_object
        end
        @valid_member = member.valid?
      end
      @eligible_to_join = @eligible_to_join_roles.present?
      @eligible_to_join_directly = @eligible_to_join_directly_roles.present?
    end
  end

  def get_eligibility_message
    @show_roles = true
    default_eligibility_message = "feature.member.content.not_eligible_v1_html".translate(program: _program, contact_admin: get_contact_admin_path(@program), role_names: RoleConstants.human_role_string(@roles, program: program))
    if @not_eligible_to_join_roles.size == NOT_ELIGIBLE_ROLE
      role1, role2 = @not_eligible_to_join_roles
      if role1.eligibility_message.present? && role2.eligibility_message.present?
        message = role1.eligibility_message.downcase.strip == role2.eligibility_message.downcase.strip ? role1.eligibility_message.strip : [role1.eligibility_message, role2.eligibility_message].join("\n\n")
      else
        message = role1.eligibility_message.presence || role2.eligibility_message.presence || default_eligibility_message
      end
    else
      message = @not_eligible_to_join_roles.first.eligibility_message.presence || default_eligibility_message
    end
    return chronus_format_text_area(message)
  end

  # To be removed when name and email fields are to be removed from membership request.
  def handle_email_validation_error
    return if @member.valid? || !@member.errors.has_key?(:email)

    @membership_request.email = @member.email
    @membership_request.errors.add(:email, @member.errors[:email].join(","))
  end

  def handle_exception_on_membership_request_save(new_record = false)
   error =
    if !@member.valid?
      "Member not valid: #{@member.errors.full_messages.join(" - ")}"
    elsif !@membership_request.valid?
      "Membership Request not valid: #{@membership_request.errors.full_messages.join(" - ")}"
    elsif @profile_answers_updation_error
      "Profile answers updation failure"
    elsif new_record
      if !(wob_member.present? || @member.can_signin?)
        "Wob member not present and member cannot siginin"
      elsif (@membership_request.joined_directly? && !@new_user.valid?)
        "Request is joined directly and user not valid"
      elsif !@eligible_to_join
        "Member not eligible to join"
      end
    end
    if error.present?
      @log_error = true
      action = new_record ? "creation" : "updation"
      error = "Membership request #{action} failure. Additional Info: #{error}"
      raise error
    end
  end

  def redirect_valid_new_user
    if @user.present? && wob_member.present?
      notice = "flash_message.membership.add_role_directly".translate(role_name: RoleConstants.human_role_string(@roles, program: @program, no_capitalize: true, articleize: true), prog_name: @program.name)
      notice = notice + " " + "flash_message.membership.add_role_directly_not_eligible".translate(role_name: RoleConstants.human_role_string(@not_eligible_to_join_roles.collect(&:name), program: @program, no_capitalize: true, articleize: true)) if @not_eligible_to_join_roles.present?
      flash[:notice] = notice
      redirect_to edit_member_path(wob_member, root: @program.root, first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    else
      welcome_the_new_user(@new_user, skip_login: wob_member.present?, locale: cookies[:current_locale], not_eligible_to_join_roles: @not_eligible_to_join_roles, newly_added_roles: @new_user.role_names)
    end
  end

  def get_eligible_roles
    @eligible_to_join_directly ? @eligible_to_join_directly_roles.collect(&:name) : @eligible_to_join.present? ? @eligible_to_join_roles.collect(&:name) : @roles
  end

  def get_membership_questions_for_roles
    membership_questions_for_roles = {}
    role_names = current_program.roles.collect(&:name)
    role_names.each do |role_name|
      membership_questions_for_roles[role_name] = current_program.membership_questions_for(role_name, need_translations: true)
    end
    membership_questions_for_roles
  end

  def get_filterable_questions
    roles = current_program.roles.non_administrative.collect(&:name)
    current_program.membership_questions_for(roles, need_translations: true).select { |q| q.non_default_type? && !q.file_type? }
  end

  def set_and_get_pending_membership_requests(email, member_id)
    @pending_membership_requests = @program.membership_requests.pending.where(email: email).or(@program.membership_requests.pending.where(member_id: member_id))
  end
end