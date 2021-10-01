class ProgramInvitationsController < ApplicationController
  include Report::MetricsUtils
  include CampaignManagement::CampaignsHelper
  include EmailFormatCheck

  LIST_PER_PAGE = 25
  MAX_EMAILS_FOR_VIEW = 5

  respond_to :json, only: :index

  before_action :set_bulk_dj_priority, only: [:bulk_confirmation_view, :bulk_destroy, :bulk_update]
  before_action :fetch_invites, :only => [:bulk_update, :bulk_destroy, :export_csv]
  before_action :fetch_campaign, :only => [:new, :index]
  before_action :fetch_other_invitations, :only => [:new, :index]

  allow :user => :is_admin?, :except => [:new, :create]
  allow :exec => :check_can_send_invite, :only => [:new, :create]
  before_action :fetch_filter_params, :only => [:index]

  skip_before_action :back_mark_pages, :only => [:new, :create, :bulk_confirmation_view]

  # List of invitations
  #
  # ==== Url Params
  # *<tt>filter</tt> : role whose sent invitations to show
  #
  def index
    @metric = get_source_metric(current_program, params[:metric_id])
    @src_path = params[:src]
    @my_filters = initialize_my_filters
    @sent_by_admin = params[:other_invitations].nil?
    declare_default_sort(params)
    @presenter = GenericKendoPresenter.new(ProgramInvitation, GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(current_program, @sent_by_admin), params)
    @program_invitations = @presenter.list
    build_program_invitations_hash if @sent_by_admin
    @total_count = @presenter.total_count

    @overall_analytics, @analytic_stats = @campaign.get_analytics_details(params) if @sent_by_admin
    @skip_rounded_white_box_for_content = true
    @entries_in_page = [ProgramInvitationsHelper::DEFAULT_PAGE_SIZE, @total_count].min
    respond_to do |format|
      format.html
      format.json
    end
  end

  def select_all_ids
    declare_default_sort(params)
    presenter = GenericKendoPresenter.new(ProgramInvitation, GenericKendoPresenterConfigs::ProgramInvitationGrid.get_config(current_program, params[:sent_by_admin].to_s.to_boolean), params)
    render json: { ids: presenter.list.map{ |program_invitation| program_invitation.id.to_s }, total_count: presenter.total_count }.to_json
  end

  # Creates ProgramInvitation records, one per the recipient in
  # params[:recipients] and with role params[:role] which is either
  # RoleConstants::STUDENT_NAME or RoleConstants::MENTOR_NAME
  #
  def create
    # Panic if no recipients
    if params[:mentor_recipients].blank? && params[:student_recipients].blank?
      if params[:recipients].blank?
        flash[:error] = "flash_message.program_invitation_flash.recipients_empty".translate
        redirect_to invite_users_path and return
      elsif params[:role].blank? || (@role_names = params[params[:role]]).blank?
        flash[:error] = "flash_message.program_invitation_flash.roles_empty".translate
        session[:program_invitations_recipient_email_ids] = params[:recipients]
        redirect_to invite_users_path and return
      end
    end

    # Create the records in a transaction
    #
    # XXX We are not doing a bulk create since it is not atomic and results in
    # records created even if one of them had error.
    #
    is_current_user_admin = current_user.is_admin?

    allow! :exec => lambda { is_current_user_admin || check_invitation_roles_permission }
    invites = make_invitations_for_role(params[:recipients], params[:message], params[:locale], @role_names, role_type: params[:role])
    total_invites_count = params[:recipients].split(",").count

    has_invalid_invitations = @existing_members.present? || @invalid_domain_emails.present? || @invalid_emails.present?
    failed_invites = @existing_members.collect(&:email) + @invalid_emails + @invalid_domain_emails
    failed_emails = failed_invites.join(COMMON_SEPARATOR)

    if has_invalid_invitations
      if failed_emails.present?
        flash[:error] = failed_invites_flash_message(invites, failed_invites, total_invites_count, is_current_user_admin)
      else
        # Error because of some other field.
        flash[:error] = "flash_message.program_invitation_flash.program_invitation_error".translate
      end
    else
      # If all invitations saved successfully.
      # clear session[:program_invitations_recipient_email_ids] set previously
      session.delete(:program_invitations_recipient_email_ids)
      flash[:notice] = is_current_user_admin ? "flash_message.program_invitation_flash.created_v3".translate + " " + "flash_message.program_invitation_flash.update_invitation_listing_v2".translate : "flash_message.program_invitation_flash.created_v3".translate
    end
    ProgramInvitation.delay(queue: DjQueues::HIGH_PRIORITY).send_invitations(invites.collect(&:id), @current_program.id, current_user.id, skip_sending_instantly: true, is_sender_admin: is_current_user_admin)
    is_current_user_admin ? (redirect_to program_invitations_path) : (redirect_to_back_mark_or_default program_root_path)
  end

  # Invite page through which admin invites students and mentors.
  #
  # ==== Params
  # role :: the role string - students or mentors or admins
  #
  def new
    @recipient_email = params[:recipient_email].presence || session[:program_invitations_recipient_email_ids]
    @invite_for_roles = params[:invitation_roles] if params[:invitation_roles].present?
    @role = handle_old_invite_users_role_format(params[:role])
    @display_role_string = @role.present? ? @current_program.term_for(CustomizedTerm::TermType::ROLE_TERM, @role).pluralized_term : @role
  end

  def bulk_update
    @program_invitation_ids_to_resend = @current_program.program_invitations.joins(user: :roles).where(id: @program_invitation_ids, use_count: 0, roles: { name: RoleConstants::ADMIN_NAME }).pluck(:id)
    ProgramInvitation.delay(queue: DjQueues::HIGH_PRIORITY).send_invitations(@program_invitation_ids_to_resend, current_program.id, current_user.id, update_expires_on: true, skip_sending_instantly: true, is_sender_admin: true, action_type: "Resend Invitations")
    @message = "feature.program_invitations.content.resent_successfully".translate if @program_invitation_ids_to_resend.present?
    render :update
  end

  def bulk_destroy
    program_invitations = @current_program.program_invitations.where(id: @program_invitation_ids)
    @message = "flash_message.program_invitation_flash.deleted_v1".translate(count: program_invitations.size)

    CampaignManagement::ProgramInvitationCampaignMessageJob.where(abstract_object_id: @program_invitation_ids, abstract_object_type: ProgramInvitation.name).delete_all
    CampaignManagement::ProgramInvitationCampaignStatus.where(abstract_object_id: @program_invitation_ids, abstract_object_type: ProgramInvitation.name).delete_all
    JobLog.where(ref_obj_id: @program_invitation_ids, ref_obj_type: ProgramInvitation.name).delete_all
    program_invitations.delete_all
    render :update
  end

  def export_csv
    allow! exec: lambda { @program_invitation_ids.present? }
    tmp_file_name = S3Helper.embed_timestamp("program_invitations.csv")
    respond_to do |format|
      format.csv { render_csv_stream(tmp_file_name) }
    end
  end

  def bulk_confirmation_view
    @bulk_action_title = params[:bulk_action_confirmation][:title]
    @bulk_action_type = params[:bulk_action_confirmation][:type].to_i
    selected_ids = params[:bulk_action_confirmation][:selected_ids].split(COMMON_SEPARATOR).map(&:to_i)
    ids_sent_to_hash = @current_program.program_invitations.where(id: selected_ids).pluck(:id, :sent_to).to_h
    @selected_ids = ids_sent_to_hash.keys
    @resend_emails = ids_sent_to_hash.values
    render partial: "program_invitations/bulk_action_confirmation.html"
  end

  private

  def declare_default_sort(params)
    return if params[:sort].present?
    params.merge!(sort: { "0" => { field: "sent_on", dir: "desc" } })
  end

  def render_csv_stream(tmp_file_name)
    CSVStreamService.new(response).setup!(tmp_file_name, self) do |stream|
      ProgramInvitation.report_to_stream(current_program, stream, @program_invitation_ids, current_member)
    end
  end

  def fetch_invites
    @program_invitation_ids = params[:selected_ids].split(COMMON_SEPARATOR).map(&:to_i)
  end

  def fetch_filter_params
    if params[:view_id].present? && (@prog_inv_view = @current_program.abstract_views.find(params[:view_id]))
      alert = @prog_inv_view.alerts.find_by(id: params[:alert_id])
      filter_params = alert.present? ? FilterUtils.process_filter_hash_for_alert(@prog_inv_view, @prog_inv_view.filter_params_hash, alert) : @prog_inv_view.filter_params_hash
      @filter_hash = params.reverse_merge(ActionController::Parameters.new(filter_params).permit!)
    else
      @filter_hash = params
    end
    @filter_hash[:sent_between_start_time], @filter_hash[:sent_between_end_time] = CommonFilterService.initialize_date_range_filter_params(@filter_hash[:sent_between])
  end

  def make_invitations_for_role(recipients, message, locale, role, options = {})
    invites=[]
    role_type = ProgramInvitation::RoleType::STRING_TO_TYPE[options[:role_type]] || ProgramInvitation::RoleType::ASSIGN_ROLE
    # Remove trailing spaces and adding condition that only one program invitation should be sent for one email
    recipient_emails = recipients.gsub(/\s/, ", ").split(",").map(&:strip).map(&:downcase).uniq.select {|email| email.present?}
    members = @current_organization.members.where(email: recipient_emails).includes(:users => [:roles])
    @existing_members = if role_type == ProgramInvitation::RoleType::ALLOW_ROLE
      members.select {|member|  member && (user = member.users.find {|user| user.program_id == (@current_program.id) }) && !user.suspended? }
    else
      members.select {|member|  member && (user = member.users.find {|user| user.program_id == (@current_program.id) }) && !user.suspended? && role.all?{|role| user.has_role?(role)}}
    end

    recipient_emails -= @existing_members.collect(&:email).map(&:downcase)

    @invalid_emails = []
    @invalid_domain_emails = []
    @invalid_emails = recipient_emails.select{ |email| ValidatesEmailFormatOf::validate_email_format(email, check_mx: true).present?}
    @invalid_domain_emails = recipient_emails.reject{ |email| email.in?(@invalid_emails) || is_allowed_domain?(email, @current_organization.security_setting)}
    recipient_emails -= (@invalid_domain_emails + @invalid_emails)
    roles = [role].flatten
    roles = @current_program.roles.where(name: role)
    recipient_emails.each do |recipient|
      program_invitation_params = { :sent_to => recipient, :message => message, :user => current_user, :locale => locale }
      invite = @current_program.program_invitations.build(program_invitation_params)
      assign_user_and_sanitization_version(invite)
      invite.roles = roles
      invite.role_type = role_type
      invite.skip_observer = true
      invite.save
      invites << invite
    end
    invites
  end

  # Role param used to be plural role names like 'mentors'. Handle those old
  # format params by singularizing them and return the role to be used.
  def handle_old_invite_users_role_format(role_name)
    res = (role_name || "").split(MembershipRequest::SEPARATOR).map do |role_name|
      @current_program.get_role(role_name)
    end
    (res.blank? || res.include?(nil)) ? "" : role_name
  end

  def check_can_send_invite
    current_user.can_invite_roles?
  end

  def check_invitation_roles_permission
    !@role_names.find{|role_name| !current_user.send("can_invite_#{role_name}s?")}
  end

  def initialize_my_filters
    my_filters = []
    my_filters << {:label => "feature.program_invitations.label.sent_between".translate, :reset_suffix => 'sent_between'} if @filter_hash[:sent_between].present?
    my_filters << {:label => 'feature.program_invitations.label.expired_invitations'.translate, :reset_suffix => 'expired_invitations'} if @filter_hash[:include_expired_invitations].present?
    return my_filters
  end

  def fetch_campaign
    @campaign = current_program.program_invitation_campaign
  end

  def fetch_other_invitations
    @other_invitations = GenericKendoPresenterConfigs::ProgramInvitationGrid.get_invitations(current_program)
  end

  def failed_invites_flash_message(invites, failed_invites, total_invites_count, is_current_user_admin)
    flash_message = ""
    # If atleast one of the emails is invalid or corresponds to already existing user or belongs to invalid domain
    flash_message = is_current_user_admin ? "flash_message.program_invitation_flash.invitations_sent_status".translate(sent_invites_count: invites.size ,total_invites: total_invites_count) + " #{'display_string.and'.translate} " + "flash_message.program_invitation_flash.update_invitation_listing".translate + " " : "flash_message.program_invitation_flash.invitations_sent_status".translate(sent_invites_count:  invites.size ,total_invites: total_invites_count) + ". " if invites.size > 0

    flash_message +=
    if @current_organization.security_setting.email_domain.present?
      "flash_message.program_invitation_flash.invalid_domain_invitations".translate(email_domains: @current_organization.security_setting.email_domain, invites: failed_invites.first(MAX_EMAILS_FOR_VIEW).join(COMMON_SEPARATOR))
    else
      "flash_message.program_invitation_flash.invalid_invitations".translate(invites: failed_invites.first(MAX_EMAILS_FOR_VIEW).join(COMMON_SEPARATOR))
    end
    if failed_invites.size > MAX_EMAILS_FOR_VIEW
      remaining_invites = failed_invites[MAX_EMAILS_FOR_VIEW..-1].join(COMMON_SEPARATOR)
      tag1 = content_tag(:span, (get_safe_string + " #{'display_string.and'.translate} " + view_context.link_to("display_string.more_with_count".translate(count: failed_invites.size - MAX_EMAILS_FOR_VIEW), "javascript: void(0)")), class: "cjs_show_and_hide_toggle_sub_selector cjs_show_and_hide_toggle_show")
      tag2 = content_tag(:span, (get_safe_string + COMMON_SEPARATOR + remaining_invites), class: "cjs_show_and_hide_toggle_sub_selector cjs_show_and_hide_toggle_content hide")
      flash_message  += content_tag(:span, tag1 + tag2, class: "cjs_show_and_hide_toggle_container")
    end
    flash_message
  end

  def build_program_invitations_hash
    @program_invitations_hash = {all_program_invitations: @program_invitations, pending_program_invitations: @program_invitations.pending.non_expired, accepted_program_invitations: @program_invitations.accepted, expired_program_invitations: @program_invitations.pending.expired}
  end

end
