class AdminMessagesController < ApplicationController
  include Report::MetricsUtils

  module ComposeType
    MEMBERS = 0
    CONNECTIONS = 1
  end
  SEPARATOR = ","

  skip_before_action :login_required_in_program, :require_program
  skip_before_action :handle_pending_profile_or_unanswered_required_qs, :only => [:new, :create]

  before_action :set_bulk_dj_priority, only: [:new_bulk_admin_message, :create]
  before_action :initialize_scope_and_access
  before_action :fetch_message, :only => [:show, :destroy]
  before_action :login_required_in_organization, :only => [:index, :show, :destroy]
  before_action :setup_negative_captcha, :only => [:new, :create]

  after_action :mark_tree_read, :only => [:show]

  allow :exec => :authorize_admin_access, :only => [:new_bulk_admin_message, :index]
  allow :exec => :authorize_show, :only => [:show]
  allow exec: :authorize_contact_admin, only: [:new]
  allow :exec => :authorize_destroy, :only => [:destroy]
  allow :exec => :can_message_to_connections?, :only => [:create]
  allow :exec => :check_if_admin_can_message_groups?  , :only => [:new, :new_bulk_admin_message]


  def new
    if @is_admin_access
      # Admin composing message for members or groups
      # 'Contact Admin' link is not shown to admin, even if he/she has other roles
      @is_admin_compose = true
      @admin_message = @current_scope.admin_messages.new
      @compose_type = params[:for_groups] && program_view? ? ComposeType::CONNECTIONS : ComposeType::MEMBERS
      @group = @current_scope.groups.find(params[:recepient_group_id]) if params[:for_groups] && params[:recepient_group_id] && program_view?
      @title = "feature.messaging.title.new_message_from_admin".translate(Admin: _Admin)
    else
      # Contact Admin - Currently 'Contact Admin' link is shown at track level only
      @admin_message = @current_scope.admin_messages.build
      @admin_message.message_receivers.build
      @admin_message.group_id = params[:group_id] if program_view? && params[:group_id].present?
      @title = "feature.messaging.title.send_message_to_admin_v1".translate(Admin: _Admin)
    end
    @hide_contact_admin = true
    @admin_message.subject = params[:subject] if params[:subject].present?
    if program_view? && request.xhr?
      # Mentoring Connection expiry date change request
      if params[:req_change_expiry].present? && params[:group_id].present?
        @connection = @current_program.groups.find(params[:group_id])
        render :partial => "admin_messages/req_change_expiry_popup.html", :layout => "program"
      elsif params[:recepient_group_id].present?
        # Sending message to group
        @connection = @current_program.groups.find(params[:recepient_group_id])
        @for_groups = params[:for_groups].present?
        render :partial => "admin_messages/new_popup.html", :layout => "program"
      end
    end   
  end

  def authorize_contact_admin
    current_member.present? || current_program.present? 
  end

  def new_bulk_admin_message
    @admin_message = @current_scope.admin_messages.build
    @src = params[:src]
    bulk_action_params = params[:bulk_action]
    if organization_view? || bulk_action_params[:members].present?
      member_ids = bulk_action_params[:members]
      # only active or dormant members are eligible for the admin message
      @selected_members = @current_organization.members.select(:id, :first_name, :last_name, :admin, :organization_id).where(id: member_ids)
      @receiver_member_ids = @selected_members.non_suspended.pluck(:id)
      @is_a_bulk_action = true
    else
      @for_groups = params[:for_groups].present?
      if @for_groups
        group_ids = bulk_action_params[:group_ids]
        @selected_groups = @current_scope.groups.select(:id, :name).where(id: group_ids)
        @is_groups_bulk_action = true
      else
        @admin_message.message_receivers.build
        if bulk_action_params.try(:[], :event).present?
          event = bulk_action_params[:event]
          @tab = event[:tab].to_i
          @program_event = @current_scope.program_events.find(event[:event_id])
          @all_receiver_users = @program_event.users_by_status(@tab)
          @receiver_member_ids = @all_receiver_users.where("users.state != ?", User::Status::SUSPENDED).pluck(:member_id)
        else
          user_ids = bulk_action_params[:users]
          # only active or pending users are eligible for the admin message
          @selected_users = @current_scope.all_users.select(:id, :member_id, :state, :program_id).includes(:member).where(id: user_ids)
          @receiver_member_ids = @selected_users.active_or_pending.pluck(:member_id)
        end
        @is_a_bulk_action = true
      end
    end
    render :partial => "admin_messages/new_popup.html", :layout => "program"
  end

  def create
    verify_params_handler or return
    build_params_handler or return
    assign_user_and_sanitization_version(@admin_message)
    save_admin_message_handler or return

    @resource = current_user.accessible_resources.find(params[:admin_message][:resource_id]) if params[:admin_message][:resource_id].present?
    return if request.xhr?

    if @success_flash
      flash[:notice] = @success_flash
      if @admin_message.parent_id
        redirect_to admin_message_path(@admin_message, root: @admin_message.program.root, from_inbox: params[:from_inbox], is_inbox: true, reply: true)
      else
        back_mark_options = {:additional_params => "#{ProgramsController::RETAIN_FLASH}=#{true}"}
        redirect_to_back_mark_or_default(program_root_path({ProgramsController::RETAIN_FLASH => true}), back_mark_options)
      end
    else
      flash[:error] = @error_flash
      error_redirect_handler
    end
  rescue VirusError
    @error_flash = "flash_message.message_flash.virus_present".translate
    return if request.xhr?
    flash[:error] = @error_flash
    error_redirect_handler
  end

  def index
    @metric = get_source_metric(current_program, params[:metric_id])
    @src_path = params[:src]
    @params_with_abstract_view_params = (params[:abstract_view_id] && (@abstract_view = current_program.abstract_views.find(params[:abstract_view_id]))) ? ActiveSupport::HashWithIndifferentAccess.new(@abstract_view.filter_params_hash).merge(params) : params
    @messages_presenter = Messages::AdminMessagesPresenter.new(wob_member, @current_scope, @params_with_abstract_view_params.slice(:tab, :page, :search_filters, :include_system_generated).merge({html_request: !request.xhr?}))
    @my_filters = @messages_presenter.my_filters
  end

  def show
    @inbox = (params[:is_inbox] == 'true')
    @from_inbox = (params[:from_inbox] == 'true')
    back_link_text = @inbox ? "feature.messaging.back_link.inbox".translate : "feature.messaging.back_link.sent_items".translate
    back_link_tab  = @inbox ? MessageConstants::Tabs::INBOX : MessageConstants::Tabs::SENT
    filters_params = permitted_filters_params
    back_link_path = if @is_admin_access && !@from_inbox
      admin_messages_path( { tab: back_link_tab }.merge(filters_params))
    else
      messages_path( { organization_level: true, tab: back_link_tab }.merge(filters_params))
    end
    @back_link = { label: back_link_text, link: back_link_path }
    @open_reply = (params[:reply].nil?) ? false : true

    if @is_admin_access
      # When admin should view this message only in program context
      if !@current_program && @admin_message.for_program?
        redirect_to admin_message_path(@admin_message, root: @admin_message.program.root, from_inbox: @from_inbox, is_inbox: @inbox, filters_params: filters_params)
        return
      end
    end
    @skip_rounded_white_box_for_content = true
  end

  def destroy
    @admin_message.mark_deleted!(wob_member)
    flash[:notice] = "flash_message.message_flash.deleted".translate
    if @admin_message.root.thread_can_be_viewed?(wob_member)
      redirect_to_back_mark_or_default admin_message_path(@admin_message.root)
    elsif @is_admin_access
      redirect_to admin_messages_path
    else
      redirect_to messages_path
    end
  end

  private

  def can_message_to_connections?
    if params[:admin_message][:connection_ids].present?
      return @current_program.ongoing_mentoring_enabled?
    end
    return true
  end

  def check_if_admin_can_message_groups?
    params[:for_groups].blank? || @current_program.ongoing_mentoring_enabled?
  end

  def fetch_message
    @admin_message = AdminMessage.find(params[:id])
  end

  def initialize_scope_and_access
    @current_scope = @current_program || @current_organization
    @is_admin_access = (logged_in_program? && current_user.is_admin?) || (logged_in_organization? && wob_member.admin?)
  end

  def authorize_admin_access
    @is_admin_access
  end

  def authorize_destroy
    @admin_message.can_be_deleted?(wob_member)
  end

  def authorize_show
    @admin_message.root.thread_can_be_viewed?(wob_member)
  end

  def mark_tree_read
    # TODO: Perf: modify mark_siblings_as_read to accomodate admin_messages
    @admin_message.root.mark_tree_as_read!(wob_member)
  end

  def error_redirect_handler
    if @admin_message.parent_id
      "feature.messaging.title.reply".translate
      redirect_to_back_mark_or_default admin_message_path(@parent_message.root)
    else
      if @is_admin_access
        @compose_type = params[:admin_message][:connection_ids] ? ComposeType::CONNECTIONS : ComposeType::MEMBERS
        @title = "feature.messaging.title.new_message_from_admin".translate(Admin: _Admin)
        @is_admin_compose = true
      else
        @title = "feature.messaging.title.send_message_to_admin_v1".translate(Admin: _Admin)
      end
      render action: "new"
    end
  end

  def verify_params_handler
    if params[:admin_message][:receiver_ids].blank? && params[:admin_message][:user_or_member_ids].blank? && params[:bulk_action].present?
      redirect_to_back_mark_or_default program_root_path
      return
    end
    return true
  end

  def build_params_handler
    @parent_message = @current_scope.admin_messages.find(params[:admin_message][:parent_id]) if params[:admin_message][:parent_id]
    if @parent_message
      allow! exec: Proc.new { logged_in_organization? && @parent_message.can_be_replied?(wob_member) }
      @admin_message = @parent_message.build_reply(wob_member, from_inbox: params[:from_inbox])
      @admin_message.content = params[:admin_message][:content]
      @admin_message.attachment = params[:admin_message][:attachment]
    else
      @admin_message = @current_scope.admin_messages.build(sender: wob_member)
      receiver_ids = params[:admin_message][:receiver_ids]
      if params[:includes_suspended].present?
        user_or_member_ids = params[:admin_message][:user_or_member_ids].split(SEPARATOR)
        receiver_ids = (program_view? ? @current_scope.all_users.where(id: user_or_member_ids).pluck(:member_id) : @current_scope.members.where(id: user_or_member_ids).pluck(:id)).join(SEPARATOR)
      end
      if receiver_ids.blank? && params[:admin_message][:user_or_member_ids].present?
        @error_flash = 'flash_message.admin_message.select_at_least_one_user'.translate
        unless request.xhr?
          flash[:error] = @error_flash
          redirect_to_back_mark_or_default program_root_path
        end
        return
      end
      if params[:admin_message][:resource_mail_subject].present?
        @admin_message.subject = params[:admin_message][:resource_mail_subject]
        @success_flash = "flash_message.admin_message.ask_a_question_success_v1".translate(Administrator: _Admin) unless params[:admin_message][:resource_id].present?
      end
      @admin_message.attributes = admin_message_params.merge({:sender_email => @captcha.values[:email]})
      @admin_message.connection_ids = params[:admin_message][:connection_ids] if params[:admin_message][:connection_ids]
      @admin_message.attachment = nil if !logged_in_organization? && @current_organization.security_setting.sanitization_version == ChronusSanitization::HelperMethods::SANITIZATION_VERSION_V2 # back end force attachments to be nil when the version is v2 and unlogged in
      @admin_message.receiver_ids = receiver_ids if receiver_ids.present?
      unless @is_admin_access
        # This is the case when a user is trying to contact admin - So there will be no receivers just a message_receiver with no member
        allow! exec: Proc.new { @admin_message.receiver_ids.blank? }
        @admin_message.message_receivers.build
      end
    end
    return true
  end

  def save_admin_message_handler
    ActiveRecord::Base.transaction do
      # lock is used for admin messages limit 10 validation if requests come at same time
      current_member.lock! if current_member
      # Captcha for offline users and non-ajax request
      if !logged_in_organization? && !simple_captcha_valid?
        flash[:error] = "flash_message.admin_message.captcha_fail".translate
        error_redirect_handler
        return
      elsif !logged_in_organization? && !@captcha.valid?
        # Negative Captcha Failed
        redirect_to_back_mark_or_default program_root_path
        return
      elsif @admin_message.save
        @success_flash ||= @is_admin_access ? "flash_message.message.succeeded".translate : "flash_message.admin_message.succeeded_v1".translate(Administrator: _Admin)
      else
        @error_flash = @admin_message.errors.full_messages.to_sentence.presence || "flash_message.message_flash.post_failure".translate
      end
      return true
    end
  end

  private

  def admin_message_params
    params[:admin_message].present? ? params[:admin_message].permit(AdminMessage::MASS_UPDATE_ATTRIBUTES[:create]) : {}
  end

  def permitted_filters_params
    return {} if params[:filters_params].blank?

    params[:filters_params].permit(:include_system_generated, search_filters: [:date_range, :sender, :receiver, :search_content, status: [:read, :unread]]).to_h
  end
end