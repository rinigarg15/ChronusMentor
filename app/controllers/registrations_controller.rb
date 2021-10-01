class RegistrationsController < ApplicationController
  include SolutionPack::ImporterUtils

  skip_before_action :login_required_in_program, only: [:new, :create, :new_admin, :create_admin, :update, :create_enrollment, :terms_and_conditions_warning, :accept_terms_and_conditions]
  skip_before_action :require_program, only: [:create, :new_admin, :create_admin, :update, :create_enrollment, :terms_and_conditions_warning, :accept_terms_and_conditions]
  skip_before_action :require_organization, only: [:new_admin, :create_admin]

  before_action :check_loggend_in_organization, only: [:create_enrollment, :terms_and_conditions_warning, :accept_terms_and_conditions]
  before_action :fetch_invitation, only: [:new, :create]
  before_action :fetch_reset_code, only: [:update]
  before_action :external_authorization, only: [:new, :create, :update]

  skip_before_action :verify_authenticity_token, only: [:create, :create_admin, :update]
  skip_before_action :back_mark_pages, only: [:new_admin]
  skip_before_action :handle_terms_and_conditions_acceptance, only: [:new, :create, :update, :terms_and_conditions_warning, :accept_terms_and_conditions]
  skip_before_action :handle_pending_profile_or_unanswered_required_qs, except: [:create_enrollment]

  allow exec: :super_console?, only: [:new_admin, :create_admin]

  def new
    @only_login = true

    if !params[:invite_error] && @program_invitation.assign_type? && wob_member.try(:terms_and_conditions_accepted?)
      create_or_update_invite_member(@program_invitation)
    else
      @member ||= @program_invitation.build_member_from_invite
      if session_import_data.present?
        @member.attributes = user_invite_params(session_import_data["Member"].pick("first_name", "last_name"))
        @profile_answers_map = session_import_data["ProfileAnswer"]
      end
    end

    return if performed?
    deserialize_from_session(Member, @member, :id, :admin)
    initialize_login_sections if @auth_config.blank? && !logged_in_organization?
  end

  def new_admin
    org_params = params[:program].delete(:organization) || params[:organization]
    domain_params = org_params[:program_domain]
    subdomain = domain_params[:subdomain]
    domain = domain_params[:domain]
    name = params[:program][:name]
    account_name = org_params[:account_name]
    subscription_type = org_params[:subscription_type]

    @organization = Organization.new(name: name, account_name: account_name, subscription_type: subscription_type)

    @program_domain = @organization.program_domains.new(subdomain: subdomain, domain: domain)
    @program_domain.organization = @organization

    params[:program][:creation_way] = params[:creation_way].to_i
    not_basic = (@organization.subscription_type != Organization::SubscriptionType::BASIC)
    features = params[:program].delete(:enabled_features)
    @enabled_features = not_basic ? features : []
    @program = Program.new(program_params(params[:program], :new_admin))
    @program.engagement_type = Program::EngagementType::CAREER_BASED_WITH_ONGOING unless not_basic
    @program.engagement_type = Program::EngagementType::CAREER_BASED unless @program.engagement_type.present?
    @program.organization = @organization
    @program.root = Program.program_root_name

    if params[:program][:creation_way] == Program::CreationWay::SOLUTION_PACK && params[:program][:solution_pack_file].present?
      @program.solution_pack_file = save_content_pack_to_be_imported(params[:program][:solution_pack_file])
      @program.student_name = "feature.custom_terms.mentee".translate
      @program.mentor_name = "feature.custom_terms.mentor".translate
    end
    administrator_term = "feature.custom_terms.admin".translate.downcase
    name_presence = @program.student_name.present? && @program.mentor_name.present?
    name_invalid = name_presence && @program.student_name.downcase == @program.mentor_name.downcase
    imported = import_profile_questions
    name_has_admin = name_presence && (@program.student_name.downcase == administrator_term || @program.mentor_name.downcase == administrator_term)
    unless @program.valid? && imported && !name_invalid && !name_has_admin
      clean_up_solution_pack_file(@program.solution_pack_file) if @program.solution_pack_file.present?
      errors_array = []
      errors_array << "flash_message.home.mentor_mentee_name_can_not_be_same".translate(mentor:"Mentor", mentee: "Mentee") if name_invalid
      errors_array << "flash_message.home.program_creation_error".translate if !@program.valid? && imported
      errors_array << "flash_message.home.mentor_mentee_name_cannot_be_admin".translate(mentor:"Mentor", mentee: "Mentee", admin: "Administrator") if name_has_admin
      errors_array += ProfileQuestion::Importer.error_messages
      flash[:error] = errors_array.join("<br/>")
      redirect_to root_path(program: params[:program].permit!.to_h, organization: org_params.permit!.to_h) and return
    end

    @member = deserialize_from_session(Member, @member, :admin)
    @member.admin = true
  end

  def create
    create_or_update_invite_member(@program_invitation, accepted_signup_terms?)
  end

  def create_enrollment
    # This check is present when user tries to submit without selecting any checkbox and JS validation is not executed.
    if params[:roles].blank?
      flash[:error] = "flash_message.enrollment.roles_cannot_be_blank".translate
      redirect_to enrollment_path and return
    end
    @program = @current_organization.programs.find(params[:program])
    allow! exec: "@program.present? && @program.allow_join_directly_in_enrollment?"
    @role_names = Array(params[:roles]) & @program.role_names_with_join_directly_or_join_directly_only_with_sso
    @member = wob_member
    unless @member.suspended?
      @user = @program.build_and_save_user!({}, @role_names, @member)
      customized_role_name = RoleConstants.human_role_string(@role_names, program: @program, no_capitalize: true, articleize: true)
      User.delay.send_welcome_email(@user.id, @role_names)
      flash[:notice] = "flash_message.enrollment.welcome".translate(role_names: customized_role_name, program_name: @program.name)
      redirect_to edit_member_path(wob_member, root: @program.root, first_visit: true, ei_src: EngagementIndex::Src::EditProfile::FIRST_TIME_COMPLETION)
    else
      flash[:error] = "email_translations.member_suspension_notification.subject".translate
      redirect_to enrollment_path
    end
  end

  # First time program creation
  def create_admin
    prog_params = params[:member].present? ? params[:member].delete(:program) : params[:program]
    enabled_features = prog_params.delete(:enabled_features) || []
    org_params = prog_params.delete(:organization)

    domain_params = org_params[:program_domain]
    subdomain = domain_params[:subdomain].presence
    domain = domain_params[:domain]
    name = prog_params[:name]
    account_name = org_params[:account_name]
    subscription_type = org_params[:subscription_type]

    @organization = Organization.new(name: name, account_name: account_name, subscription_type: subscription_type)
    @organization.creating_using_solution_pack = (prog_params[:creation_way].to_i == Program::CreationWay::SOLUTION_PACK)
    program_domain = @organization.program_domains.new(subdomain: subdomain, domain: domain)
    program_domain.organization = @organization
    @program = Program.new(program_params(prog_params, :create_admin))
    @program.organization = @organization
    @program.root = Program.program_root_name
    @program.solution_pack_file = prog_params[:solution_pack_file]
    @member = Member.new(member_params(:create_admin))
    @member.organization = @organization
    @member.admin = true

    # We validate the chronus user record, and if it is fine, proceed to creating the program and then the chronus user.
    if @member.valid?
      if (sections_data = session[:sections]).present?
        # build objects by saved hash
        ProfileQuestion::Importer.build_from_hash(sections_data, @organization, @program)
        @program.skip_organization_validation = true
        session[:sections] = nil
      end
      if @organization.save && @program.organization.reload && @program.save
        # Program successfully saved. Now, save the user. This save should not result in any error since we have already validated it.
        @program.enable_feature(FeatureName::CALENDAR) if enabled_features.include?(FeatureName::CALENDAR)
        @member.accept_terms_and_conditions! if accepted_signup_terms?
        @user = create_admin_from_member
        @program.set_owner!
        if @program.created_using_solution_pack?
          begin
            solution_pack, data_deleted = import_solution_pack(@program)
            message, message_type = get_solution_pack_flash_message(solution_pack, data_deleted)
            flash[message_type] = message
          rescue => e
            notify_airbrake("solution_pack.error.program_creation_failed".translate)
            @program.organization.destroy
            clean_up_solution_pack_file(@program.solution_pack_file)
            flash[:error] = "flash_message.program_flash.failed_from_sp".translate(program: "program")
            redirect_to root_path and return
          end
        end

        # Login user and set current program.
        self.current_user = @user
        @current_program = @program
        @current_organization = @organization
        ChronusMailer.welcome_message_to_admin(@user).deliver_now # Send welcome email to admin.
        session[:new_organization_id] = @organization.id
        redirect_to program_edit_path(first_visit: 1)
      else
        # Take the user back to landing page if there are any errors in creating the program. Ideally this should not happen since we validated the
        # program details before rendering the signup page
        flash[:error] =  "flash_message.home.program_creation_error".translate
        redirect_to root_path(program: prog_params.permit!.to_h, organization: org_params.permit!.to_h) and return
      end
    else
      # Errors in user record. Render admin signup form again
      serialize_to_session(@member)
      redirect_to new_admin_registrations_path(program: prog_params.permit!.to_h, organization: org_params.permit!.to_h)
    end
  end

  def update
    @member.time_zone ||= params[:member].delete(:time_zone)
    @member.attributes = member_params(:update)

    member_save_wrapper new_user_followup_users_path(reset_code: @password.reset_code, auth_config_id: @auth_config.try(:id)) do
      @password.destroy

      user = @member.user_in_program(current_program) if program_view?
      if program_view? && user.present?
        welcome_the_new_user(user, newly_added_roles: user.role_names)
      else
        welcome_the_new_member(@member)
      end
    end
  end

  def terms_and_conditions_warning
    # redirect away if user is already accepted T&C
    if wob_member.terms_and_conditions_accepted?
      redirect_to_back_mark_or_default program_view? ? program_root_path : root_path
    end
  end

  def accept_terms_and_conditions
    wob_member.time_zone = params[:time_zone] if params[:time_zone].present? && !wob_member.time_zone.present?
    wob_member.accept_terms_and_conditions!
    redirect_to_back_mark_or_default program_view? ? program_root_path : root_path
  end

  protected

  def create_admin_from_member
    user  = @member.users.new
    user.program = @program
    user.role_names = [RoleConstants::ADMIN_NAME]
    user.save!
    return user
  end

  private

  def member_params(action)
    params[:member].permit(Member::MASS_UPDATE_ATTRIBUTES[:from_registration][action])
  end

  def program_params(prog_params, action)
    prog_params.permit(Program::MASS_UPDATE_ATTRIBUTES[:from_registration][action])
  end

  def external_authorization
    session[:invite_code] = params[:invite_code]

    return if logged_in_organization? || new_user_authenticated_externally?
    return if @auth_config.blank? || @auth_config.indigenous?

    login_required_in_program(@auth_config.id)
  end

  def import_profile_questions
    ok = true
    ProfileQuestion::Importer.reset_errors
    if (stream = params[:profile_questions]).present?
      if sections_attributes = ProfileQuestion::Importer.import_csv(stream, @organization, @program)
        session[:sections] = sections_attributes
      else
        ok = false
      end
    end
    ok
  end

  def check_loggend_in_organization
    redirect_to root_organization_path unless logged_in_organization?
  end

  def fetch_invitation
    @program_invitation = current_program.program_invitations.find_by(code: params[:invite_code])
    return handle_invalid_invite if @program_invitation.blank?

    @member = @program_invitation.sent_to_member
    @auth_config = get_and_set_current_auth_config
    if @member.present?
      if @member.suspended?
        handle_suspended_invite_member
      elsif @member.can_signin?
        handle_invite_member_who_can_signin(@member, @program_invitation)
      end
    end

    return if performed?
    if @program_invitation.expired? || (@program_invitation.use_count > 0)
      handle_invalid_invite
    elsif !is_invite_email_valid?(@program_invitation)
      handle_invalid_invite("flash_message.user_flash.mismatch_email_html")
    elsif logged_in_organization? && (@member != wob_member)
      logout_killing_session!
      do_redirect new_registration_path(invite_code: @program_invitation.code)
    end
  end

  def handle_invalid_invite(error_message_key = nil)
    session[:invite_code] = nil
    error_message_key ||= "flash_message.user_flash.invalid_invitation_html"
    flash[:error] = error_message_key.translate(program_admin: get_contact_admin_path(@current_program, label: "#{_program} #{_admin}"))
    do_redirect root_path
  end

  def handle_suspended_invite_member
    flash[:error] = "flash_message.user_session_flash.suspended_member_v2".translate(program: _program, administrator: _admin)
    do_redirect root_path
  end

  def handle_invite_member_who_can_signin(member, program_invitation)
    user = member.user_in_program(current_program)
    invited_for_new_roles = user.blank? || user.suspended? || (program_invitation.role_names - user.role_names).any?

    unless invited_for_new_roles
      flash[:info] = "flash_message.membership.existing_user_different_uid".translate(program: _program) unless logged_in_organization?
      do_redirect root_path and return
    end

    unless logged_in_organization?
      session[:invite_code] = program_invitation.code
      handle_member_who_can_signin_during_signup(member)
    end
  end

  def is_invite_email_valid?(program_invitation)
    return true unless new_user_authenticated_externally?
    return true if new_user_external_auth_config.linkedin_oauth?

    email = session_import_data_email
    email.blank? || email.strip.downcase == program_invitation.sent_to.strip.downcase
  end

  def create_or_update_invite_member(program_invitation, accepted_signup_terms = true)
    @member ||= program_invitation.build_member_from_invite
    if params[:member].present?
      @member.attributes = user_invite_params(params[:member])
      @member.time_zone = params[:member][:time_zone] if @member.time_zone.blank?
    end

    member_save_wrapper new_registration_path(invite_code: session[:invite_code], invite_error: true, auth_config_id: @auth_config.try(:id)), accepted_signup_terms do
      create_or_update_invite_user(@member, program_invitation)
    end
  end

  def member_save_wrapper(error_url, accepted_signup_terms = true)
    begin
      assign_external_login_params(@member)
      ActiveRecord::Base.transaction do
        @member.save!
        raise "Member should be able to signin!" unless @member.can_signin?

        session[:invite_code] = session[:reset_code] = nil
        Language.set_for_member(@member, current_locale)
        @member.accept_terms_and_conditions! if accepted_signup_terms
        create_profile_answers_from_sso_response(@member, params[:profile_answers]) if params[:profile_answers].present?
        yield
      end
    rescue => e
      logger.error "--- #{e.message} ---"
      if request.xhr?
        render action: :create
      else
        serialize_to_session(@member)
        redirect_to error_url
      end
    end
  end

  def create_or_update_invite_user(member, program_invitation)
    new_role_names = program_invitation.role_names
    new_role_names &= params[:roles] if program_invitation.allow_type?
    return if new_role_names.blank?

    member.promote_as_admin! if @current_organization.standalone? && new_role_names.include?(RoleConstants::ADMIN_NAME)

    existing_role_names = member.user_roles_in_program(current_program)
    user_creation_options = program_invitation.is_sender_admin? ? { admin: program_invitation.user } : {}
    user = current_program.build_and_save_user!({}, new_role_names, member, user_creation_options)
    program_invitation.update_use_count
    welcome_the_new_user(user, newly_added_roles: (new_role_names - existing_role_names))
  end

  def user_invite_params(invite_params)
    return invite_params unless invite_params.is_a?(ActionController::Parameters)
    invite_params.permit(Member::MASS_UPDATE_ATTRIBUTES[:new_user_invite])
  end

  # TODO: Multiple field question types like education, experience,... are not handled.
  def create_profile_answers_from_sso_response(member, profile_answers_hash)
    questions = @current_organization.profile_questions.includes(question_choices: :translations)
    questions_map = questions.index_by(&:id)
    multifield_question_ids = questions.multi_field_questions.pluck(:id)

    profile_answers_hash.each do |question_id, answer_text|
      question = questions_map[question_id.to_i]
      next if !question.present? || !answer_text.present? || multifield_question_ids.include?(question.id) || question.file_type? || question.date?
      begin
        profile_answer = (member.answer_for(question).present? ? member.answer_for(question) : ProfileAnswer.new(ref_obj_id: member.id, ref_obj_type: Member.name, profile_question: question))
        profile_answer.answer_value = {answer_text: answer_text, question: question, from_import: true}
        profile_answer.handle_location_answer(question, answer_text)
        # TODO_DATE_PROFILE : Enable it after handling errors
        # profile_answer.handle_date_answer(question, answer_text)
        profile_answer.save!
      rescue => e
        notify_airbrake("New member profile answer creation failure - MemberId: #{member.id} ProfileAnswers: #{profile_answers_hash} Exception: #{e.message}")
      end
    end
    session[:new_user_import_data][@current_organization.id] = nil if session[:new_user_import_data].present?
  end

end