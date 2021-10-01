class AnnouncementsController < ApplicationController
  allow :user => :can_manage_announcements?, :except => [:index, :show, :mark_viewed]
  before_action :fetch_announcement, :only => [:show, :edit, :update, :mark_viewed]
  allow :exec => :can_access_show, :only => [:show]

  def index
    @announcements = @current_program.announcements.for_user(current_user)

    if current_user.can_manage_announcements?
      @drafted_announcements = @announcements.drafted.ordered.paginate(:page => params[:drafted], :per_page => PER_PAGE)
      @published_announcements = @announcements.published.ordered.paginate(:page => params[:published], :per_page => PER_PAGE)
    else
      @published_announcements = @announcements.published.not_expired.ordered.paginate(:page => params[:page], :per_page => PER_PAGE)
    end
  end

  def show
  end

  def new
    # If params[:survey_id] is passed, it means announcement for publishing a
    # survey.
    @survey = @current_program.surveys.find(params[:survey_id]) if params[:survey_id]
    @announcement = Announcement.new
  end

  def edit
  end

  def create
    # Set the current user as the admin of the new announcement.
    role_names = params[:announcement].delete(:recipient_role_names)
    announcement_params = get_announcement_params(:create)
    @announcement = @current_program.announcements.build(announcement_params)
    @announcement.recipient_role_names = role_names
    @announcement.admin = current_user
    assign_user_and_sanitization_version(@announcement)

    if @announcement.save
      flash[:notice] = get_announcement_creation_flash(@announcement)
      redirect_to @announcement
    else
      flash[:error] = @announcement.errors.full_messages.to_sentence.presence
      render :action => :new
    end

  rescue VirusError
    flash[:error] = "flash_message.announcement_flash.virus_present".translate
    redirect_to new_announcement_path
  end

  def update
    role_names = params[:announcement].delete(:recipient_role_names)
    status = params[:announcement].delete(:status) || Announcement::Status::PUBLISHED

    # Announcement has an attachment and it has to be removed
    @announcement.attachment = nil if (params[:remove_attachment] and @announcement.attachment.exists?)

    old_status = @announcement.status
    @announcement.status = status
    handle_role_changes(role_names)
    assign_user_and_sanitization_version(@announcement)

    announcement_params = get_announcement_params(:update)

    if @announcement.update_attributes(announcement_params.merge(:user_id => current_user.id))
      flash[:notice] = get_announcement_updation_flash(@announcement, old_status)
      redirect_to @announcement
    else
      flash.now[:error] = @announcement.errors.full_messages.to_sentence.presence
      errors = @announcement.errors
      @announcement.attachment.destroy if errors[:attachment_content_type].presence || errors[:attachment_file_size].presence
      render :action => :edit
    end

  rescue VirusError
    flash[:error] = "flash_message.announcement_flash.virus_present".translate
    redirect_to edit_announcement_path(@announcement)
  end

  def destroy
    announcement = @current_program.announcements.find(params[:id])
    destroy_message = announcement.published? ? "flash_message.announcement_flash.deleted_v1".translate : "flash_message.announcement_flash.discarded".translate
    announcement.destroy
    flash[:notice] = destroy_message
    redirect_to announcements_path
  end

  def send_test_emails
    announcement = params[:id].blank? ?
      @current_program.announcements.new :
      @current_program.announcements.find(params[:id])

    announcement.attributes = test_mail_announcement_params.merge(:wants_test_email => true)
    announcement.notification_list_for_test_email = get_valid_emails(announcement.notification_list_for_test_email)
    announcement.title = "feature.announcements.label.no_title".translate if announcement.title.blank?
    @email_list = announcement.notification_list_for_test_email
    announcement.send_test_emails
  end

  def mark_viewed
    @working_on_behalf = working_on_behalf?
    @announcement.mark_announcement_visibility_for_user(current_user.id, @working_on_behalf)
    @unviewed_announcements_count = current_user.get_active_unviewed_announcements_count
  end

  protected

  def can_access_show
    current_user.can_manage_announcements? || @announcement.published?
  end

  private

  def get_announcement_params(action)
    params[:announcement].present? ? format_announcement_params(params[:announcement].permit(Announcement::MASS_UPDATE_ATTRIBUTES[action])) : {}
  end

  def format_announcement_params(announcement_params)
    announcement_params[:expiration_date] = get_en_datetime_str(announcement_params[:expiration_date]) if announcement_params[:expiration_date].present?
    announcement_params[:email_notification] = announcement_params[:email_notification].to_i if announcement_params[:email_notification].present?
    announcement_params
  end

  def test_mail_announcement_params
    params[:test_announcement].present? ? params[:test_announcement].permit(Announcement::MASS_UPDATE_ATTRIBUTES[:send_test_emails]) : {}
  end

  def fetch_announcement
    @announcement = @current_program.announcements.for_user(current_user).find(params[:id])
  end

  def get_announcement_creation_flash(announcement)
    if announcement.published?
      "flash_message.announcement_flash.published".translate
    elsif announcement.drafted?
      "flash_message.announcement_flash.drafted".translate
    end
  end

  def handle_role_changes(role_names)
    #roles can be updated only for drafted announcements
    if @announcement.drafted? && !role_names.present?
      @announcement.recipient_roles.destroy_all
    else
      @announcement.recipient_role_names = role_names
    end
  end

  def get_announcement_updation_flash(announcement, old_status)
    if old_status == Announcement::Status::DRAFTED && announcement.published?
      "flash_message.announcement_flash.published".translate
    else
      "flash_message.announcement_flash.updated_v1".translate
    end
  end
end
