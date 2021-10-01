class PasswordsController < ApplicationController
  skip_before_action :login_required_in_program, :require_program, :back_mark_pages

  skip_before_action :verify_authenticity_token, only: [:update_password]
  before_action :store_signup_roles_in_session, only: :reset

  module CurrentPassStatus
    BLOCKED  = 0
    WRONG = 1
  end

  def new
    @password = Password.new
  end

  def create
    @password = Password.new(password_params(:create))
    @password.member = @current_organization.members.find_by(email: @password.email)
    @password.strip_whitespace_from(@password.email)

    is_email_valid = ValidatesEmailFormatOf::validate_email_format(@password.email, check_mx: false).nil?
    if !is_email_valid || !simple_captcha_valid?
      @error_message = is_email_valid ? "flash_message.admin_message.captcha_fail".translate : "flash_message.password_flash.invalid_email".translate
    else
      ChronusMailer.forgot_password(@password, @current_organization).deliver_now if @password.save
      program_administrator = @current_program.present? ? get_contact_admin_path(@current_program, label: 'display_string.program_administrator'.translate(program: _program)) : 'display_string.program_administrator'.translate(program: _program)
      flash[:notice] = "flash_message.password_flash.creation_success_html".translate(email: @password.email, program_administrator: program_administrator.html_safe, program: program_context.name)
      do_redirect root_path
    end
  end

  #This action is for reactivating the user account, after it has been blocked due exceeding of login attempts
  def reactivate_account
    email = params[:email]
    member = @current_organization.members.find_by(email: email)
    if member.present?
      member.send_reactivation_email
    end
    flash[:notice] = "flash_message.password_flash.resent_reactivation".translate
    redirect_to program_root_path
  end

  # Page where the user can change his/her password. The entry point is from
  # forgot password email/new mentor email for those added by admin
  #
  def reset
    # Presence of reset code means reset password page.
    if params[:reset_code] && (@password = Password.find_by(reset_code: params[:reset_code]))
      set_title_for_reset_page
      @member = @password.member
      deserialize_from_session(Member, @member, :admin)
    else
      # Invalid reset code. Take user to landing page.
      flash[:error] = "flash_message.password_flash.change_invalid_code".translate
      redirect_to program_root_path and return
    end
  end

  def update_password
    @password = Password.find_by(reset_code: params[:reset_code])
    is_through_account_settings = @password.nil? && logged_in_organization?

    # No/invalid reset code. Panic otherwise.
    if !is_through_account_settings && @password.nil?
      flash[:error] = "flash_message.password_flash.change_invalid_code".translate
      redirect_to program_root_path and return
    end

    @member = is_through_account_settings ? wob_member : @password.member
    current_pass_status = authenticate_current_password(is_through_account_settings, @member, params[:member][:current_password])
    if current_pass_status == CurrentPassStatus::BLOCKED
      redirect_to account_settings_path and return
    elsif current_pass_status == CurrentPassStatus::WRONG
      render "/members/account_settings" and return
    end
    # We use User record for handling and showing errors in the form.
    @member.password = params[:member][:password]
    @member.password_confirmation = params[:member][:password_confirmation]
    @member.validate_password = true

    unless @member.can_update_password?
      flash[:error] = "flash_message.password_flash.has_password_history".
      translate(count: @current_organization.security_setting.password_history_limit)
      redirect_to account_settings_path and return if is_through_account_settings
      render :reset and return
    end

    if @member.save

      @member.sign_out_of_other_sessions(request.session_options[:id], cookies[:auth_token], is_mobile_app? && cookies.signed[MobileV2Constants::MOBILE_V2_AUTH_TOKEN])

      # If reset password, destroy the record.
      @password.destroy if @password

      if is_through_account_settings
        # Take user to home page if logged in.
        flash[:notice] = "flash_message.password_flash.change_success_single_program".translate
        redirect_to program_root_path
      else
        # Password has been changed. Take user to login page and ask him to
        # login with the new password.
        if @member.organization.login_attempts_enabled? && @member.login_attempts_exceeded?
          @member.reactivate_account!(false)
          flash[:notice] = "flash_message.password_flash.account_reactivated".translate
        else
          flash[:notice] = "flash_message.password_flash.change_from_reset_success".translate
        end
        session[:email] = @member.email
        redirect_to login_path(auth_config_id: @current_organization.chronus_auth.try(:id))
      end
    else
      if @password
        render :reset
      else
        serialize_to_session(@member)
        redirect_to account_settings_path
      end
    end
  end

  private

  def password_params(action)
    params.require(:member_email).permit(Password::MASS_UPDATE_ATTRIBUTES[action])
  end

  def set_title_for_reset_page
    @title =
      if params[:reactivate_account].present?
        "feature_password.title.reactivate".translate
      elsif params[:password_expiry].present?
        "feature_password.title.reset".translate
      else
        "feature_password.title.change".translate
      end
  end

  def authenticate_current_password(is_through_account_settings, member, current_password)
    return unless is_through_account_settings

    auth_obj = ProgramSpecificAuth.authenticate(@current_organization.chronus_auth, @member.email, params[:member][:current_password])
    return if auth_obj.authenticated? || auth_obj.password_expired?

    if auth_obj.account_blocked? || auth_obj.member_suspended? || auth_obj.no_user_existence?
      flash[:error] = "flash_message.password_flash.contact_admin_v1_html".translate(program: _program, administrator: _admin)
      return CurrentPassStatus::BLOCKED
    elsif auth_obj.authentication_failure?
      member.errors.add(:current_password, "activerecord.custom_errors.member.invalid_current_password".translate)
      deserialize_from_session(Member, member, :admin)
      return CurrentPassStatus::WRONG
    end
  end
end