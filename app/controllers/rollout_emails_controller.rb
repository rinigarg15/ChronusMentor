class RolloutEmailsController < ApplicationController

  skip_before_action :require_program, :login_required_in_program
  before_action :login_required_in_organization
  allow :exec => :check_management_access
  before_action :fetch_email, :only => [:rollout_popup, :rollout_switch_to_default_content, :rollout_keep_current_content, :rollout_dismiss_popup_by_admin]

  def rollout_popup
    @edit_page = params[:edit_page]
    @new_source = @email.default_email_content_from_path(@email.mailer_attributes[:view_path])
    @new_subject = @email.mailer_attributes[:subject].call
    @old_source = @mailer_template.source || @new_source
    @old_subject = @mailer_template.subject || @new_subject
  end

  def update_all
    non_customized = params[:non_customized].present?
    current_program_or_organization.reset_mails_content_and_update_rollout(only_copied_content: non_customized)
    @current_organization.reset_mails_content_and_update_rollout(only_copied_content: non_customized) if @current_organization.standalone?
    flash[:notice] = non_customized ? "feature.email_customization.rollout.update_non_coustomized_successful".translate : "feature.email_customization.rollout.update_all_successful".translate
    redirect_to mailer_templates_path
  end

  def rollout_keep_current_content
    correct_level.actioned_rollout_emails.create!(email_id: @uid, action_type: RolloutEmail::ActionType::KEEP_CURRENT_CONTENT)
    if request.xhr?
      head :ok
    else
      redirect_to edit_mailer_template_path(@uid)
    end
  end

  def rollout_switch_to_default_content
    if @mailer_template.enabled
      @mailer_template.destroy
    else
      @mailer_template.clear_subject_and_content(current_member)
    end
    correct_level.actioned_rollout_emails.create!(email_id: @uid, action_type: RolloutEmail::ActionType::SWITCH_TO_DEFAULT_CONTENT)
    redirect_to edit_mailer_template_path(@uid)
  end

  def dismiss_rollout_flash_by_admin
    current_user_or_member.dismissed_rollout_emails.create!
    @current_member.dismissed_rollout_emails.create! if @current_organization.standalone?
  end

  def rollout_dismiss_popup_by_admin
    correct_user_level.dismissed_rollout_emails.create!(email_id: @uid)
    redirect_to edit_mailer_template_path(@uid)
  end

  private

  def fetch_email
    @uid = params[:id]
    @email = ChronusActionMailer::Base.get_descendant(@uid)
    @email_hash = @email.mailer_attributes
    set_correct_level(@uid)
    @mailer_template = correct_level.mailer_templates.find_by(uid: @uid)
  end

  def check_management_access
    program_view? ? current_user.is_admin? : current_member.admin?
  end

  def set_correct_level(uid)
    email = ChronusActionMailer::Base.get_descendant(uid)
    email_hash = email.mailer_attributes
    @correct_level = (email_hash[:level]==EmailCustomization::Level::ORGANIZATION) ? @current_organization : @current_program
    @correct_user_level = (email_hash[:level]==EmailCustomization::Level::ORGANIZATION) ? @current_member : @current_user
  end

  def correct_level
    @correct_level
  end

  def correct_user_level
    @correct_user_level
  end
end