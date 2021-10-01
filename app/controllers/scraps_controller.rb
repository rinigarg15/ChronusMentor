class ScrapsController < ApplicationController
  include ScrapExtensions
  include ConnectionFilters
  include MentoringModelUtils

  skip_before_action :login_required_in_program, :only => [:show, :destroy] # Allowing suspended users to read scraps at inbox.

  before_action :fetch_scrap, :only => [:show, :destroy, :reply]
  before_action :check_logged_in_organization, :only => [:show, :destroy]
  before_action :fetch_group_or_meeting, :only => [:index, :destroy, :get_scraps_for_homepage]
  before_action :fetch_current_connection_membership, :only => [:index]
  allow :exec => :check_action_access_for_ref_obj, :only => [:index, :get_scraps_for_homepage]
  allow :exec => :check_meeting_member, :only => [:index]
  before_action :set_group_profile_view, only: [:index]
  before_action :set_from_find_new, only: [:index], if: :is_ref_obj_pending_group?
  before_action :prepare_template, :only => [:index]
  before_action :update_login_count, :only => [:index], unless: :is_ref_obj_pending_group?
  after_action :update_last_visited_tab, only: [:index], unless: :is_ref_obj_pending_group?
  after_action :mark_group_activity, :except => [:create], unless: :is_ref_obj_pending_group?
  after_action :mark_siblings_as_read, :only => [:show]
  allow :exec => :can_access_mentoring_area?, :only => [:index]

  SCRAPS_PER_PAGE = 10

  def index
    @scraps_enabled = true
    @src_path = params[:src]
    @home_page = params[:home_page].present?
    @current_occurrence_time = params[:current_occurrence_time]
    current_participant = @group.present? ? current_user : wob_member
    if (@ref_obj && !@ref_obj.has_member?(current_participant)) && current_user.is_admin?
      is_admin_viewing_scraps = true
      member_scraps = @ref_obj.scraps
    else
      @page_controls_allowed = true if @meeting.present? && @meeting.member_can_send_new_message?(current_participant)
      ref_obj_type = @ref_obj.is_a?(Group) ? Group.to_s : Meeting.to_s
      member_scraps = Scrap.of_member_in_ref_obj(wob_member.id, @ref_obj.id, ref_obj_type)
    end
    root_scrap_ids = member_scraps.present? ? member_scraps.select("DISTINCT root_id").collect(&:root_id) : []
    options = {:page => params[:scrap_page], :per_page => ScrapsController::SCRAPS_PER_PAGE, :is_admin_viewing_scraps => is_admin_viewing_scraps, home_page: @home_page }
    scraps_hash = get_scrap_messages_index(root_scrap_ids, wob_member, options)
    @scraps_attachments = scraps_hash[:messages_attachments]
    @scraps_last_created_at = scraps_hash[:messages_last_created_at]
    @scraps_index = scraps_hash[:messages_index]
    @scraps_ids = scraps_hash[:latest_messages]
    @unread_scraps_hash = scraps_hash[:unread_scraps_hash]
    assign_preloaded_contents(scraps_hash)
    @back_link = { link: session[:back_url] } if @meeting.present?
    @new_scrap = @ref_obj.scraps.new if @page_controls_allowed
  end

  def create
    @home_page = params[:home_page].to_boolean if params[:home_page].present?
    if params[:scrap][:parent_id].present?
      parent_scrap = @current_program.scraps.find(params[:scrap][:parent_id])
      allow! :exec => lambda { parent_scrap.can_be_replied?(wob_member) }
      @scrap = parent_scrap.build_reply(wob_member)
    else
      fetch_group_or_meeting
      @current_occurrence_time = params[:current_occurrence_time] if params[:current_occurrence_time].present?
      @scrap = @ref_obj.scraps.new(:sender => wob_member, :program_id => @ref_obj.program_id)
      allow! :exec => lambda { @scrap.has_group_access?(wob_member) || @scrap.has_meeting_access?(wob_member) }
    end
    @scrap.attributes = scrap_params(:create)
    @scrap.create_receivers! unless @scrap.reply?
    unless @scrap.save
      @error_message = @scrap.errors.full_messages.to_sentence.presence
      flash[:error] = @error_message unless request.xhr?
      return redirect_to_back_mark_or_default root_organization_path if (params[:from_inbox] == "true")
    end

    if @error_message.blank?
      parent_scrap.present? ? track_activity_for_ei(EngagementIndex::Activity::REPLY_MESSAGE_MENTORING_AREA) : track_activity_for_ei(EngagementIndex::Activity::CREATE_MESSAGE_MENTORING_AREA)
      flash[:notice] = "flash_message.message_flash.created".translate if !@scrap.reply? && !@home_page && @scrap.is_group_message?
    end

    if params[:from_inbox] == "true"
      @scrap.add_to_activity_log
      flash[:notice] = "flash_message.message_flash.created".translate
      if params[:scrap][:parent_id].present?
        redirect_to message_path(@scrap, :is_inbox => true, :reply => true)
      else
        redirect_to_back_mark_or_default root_organization_path
      end
    end
  rescue VirusError
    @error_message = "flash_message.message_flash.virus_present".translate
    flash[:error] = @error_message unless request.xhr?
    redirect_to_back_mark_or_default root_organization_path if (params[:from_inbox] == "true")
  end

  def show
    @home_page = params[:home_page].present? ? params[:home_page] : false
    if params[:from_inbox] == "true"
      @inbox = (params[:is_inbox] == "true")
      back_link_text = @inbox ? "feature.messaging.back_link.inbox".translate : "feature.messaging.back_link.sent_items".translate
      back_link_tab  = @inbox ? MessageConstants::Tabs::INBOX : MessageConstants::Tabs::SENT
      back_link_path = messages_path( { organization_level: true, tab: back_link_tab }.merge(permitted_filters_params))
      @back_link = { label: back_link_text, link: back_link_path }
      @open_reply = params[:reply].present?
      allow! exec: lambda { @scrap.root.thread_can_be_viewed?(wob_member) && !@scrap.is_admin_viewing?(wob_member) }
      @skip_rounded_white_box_for_content = true
    else
      scraps_hash = get_preloaded_scraps_hash(@scrap.root_id, wob_member)
      assign_preloaded_contents(scraps_hash)
    end
    track_activity_for_ei(EngagementIndex::Activity::READ_MESSAGE_MENTORING_AREA) if @scrap.is_group_message?
  end

  def reply
    # Reply text box will be rendered on clicking the Reply button.
    @home_page = params[:home_page].present? ? params[:home_page].to_boolean : false
    allow! :exec => lambda { @scrap.can_be_replied?(wob_member)}
  end

  def destroy
    @home_page = params[:home_page].present? ? params[:home_page].to_boolean : false
    allow! :exec => lambda { @scrap.can_be_deleted?(wob_member) }
    @scrap.mark_deleted!(wob_member)
    @scraps_size = @scrap.root.thread_members_and_size(wob_member)[:size]
    unless request.xhr?
      flash[:notice] = "flash_message.message_flash.deleted".translate
      @scrap.root.thread_can_be_viewed?(wob_member) ? redirect_to_back_mark_or_default(scrap_path(@scrap.root)) : redirect_to(messages_path)
    end
  end

  private

  def scrap_params(action)
    params.require(:scrap).permit(Scrap::MASS_UPDATE_ATTRIBUTES[action])
  end

  # We are skipping login_required_in_program filter so on directly hitting scrap show/detsroy page should authenticate user at org_level
  def check_logged_in_organization
    redirect_to login_path and return unless logged_in_organization?
  end

  def fetch_group_or_meeting
    if @scrap
      if @scrap.is_group_message?
        @group = @scrap.ref_obj
      else
        @meeting = @scrap.ref_obj
      end
    elsif params[:group_id].present?
      @group = @current_program.groups.find(params[:group_id])
    else
      @meeting = @current_program.meetings.find(params[:meeting_id])
    end
    @ref_obj = @group || @meeting
  end

  def check_meeting_member
    return true if @meeting.nil?
    @meeting.has_member?(wob_member) || @is_admin_view
  end

  def check_action_access_for_ref_obj
    @ref_obj.is_a?(Group) ? (@ref_obj.scraps_enabled? && check_member_or_admin) : check_member_or_admin_for_meeting
  end

  def fetch_scrap
    @scrap = @current_program.scraps.find(params[:id])
  end

  def is_ref_obj_pending_group?
    @is_group_profile_view
  end

  def mark_siblings_as_read
    return unless logged_in_organization?
    @scrap.root.mark_siblings_as_read(wob_member)
  end

  def mark_group_activity
    return unless ((@scrap.present? && @scrap.is_group_message?) || @group.present?) 
    group = @group || @scrap.ref_obj
    if group && group.has_member?(@current_user)
      RecentActivity.create!(
        :programs => [@current_program],
        :ref_obj => group,
        :action_type => RecentActivityConstants::Type::GROUP_RELATED_ACTIVITY,
        :member => @curret_user,
        :target => RecentActivityConstants::Target::NONE
      )
    end
  end

  def assign_preloaded_contents(scraps_hash)
    @scraps_siblings_index = scraps_hash[:siblings_index]
    @viewable_scraps_hash = scraps_hash[:viewable_scraps_hash]
    @deleted_scraps_hash = scraps_hash[:deleted_scraps_hash]
    @preloaded = true
  end

  def permitted_filters_params
    return {} if params[:filters_params].blank?

    params[:filters_params].permit(search_filters: [:date_range, :sender, :receiver, :search_content, status: [:read, :unread]]).to_h
  end
end