class MessagesController < ApplicationController

  skip_before_action :require_program, :login_required_in_program

  before_action :login_required_in_organization
  before_action :fetch_message, :only => [:show, :destroy]
  before_action :add_custom_parameters_for_newrelic, :only => [:index]
  before_action :set_member_id_for_newrelic, :only => [:index]
  after_action :mark_siblings_as_read, :only => [:show]

  def new
    @message = @current_organization.messages.build(sender: wob_member)
    @receiver = @current_organization.members.find_by(id: params[:receiver_id])
    @src = params[:src]
    render partial: "messages/new_popup.html", :layout => "program" if request.xhr?
  end

  def create
    if params[:message][:parent_id].present?
      parent_message = @current_organization.messages.find(params[:message][:parent_id])
      allow! :exec => lambda { parent_message.can_be_replied?(wob_member) }
      @message = parent_message.build_reply(wob_member)
      @message.content = params[:message][:content]
    else
      @message = @current_organization.messages.build
      @message.attributes = message_params(:create)
    end
    @message.context_program = parent_message.present? ? parent_message.root.context_program : @current_program
    @message.attachment = params[:message][:attachment]
    allow! :exec => lambda { validate_message }
    if @message.save
      flash[:notice] = "flash_message.message_flash.created".translate
      if parent_message
        track_activity_for_ei(EngagementIndex::Activity::REPLY_USERS, {:context_place => EngagementIndex::Src::ReplyUsers::INBOX})
        redirect_to message_path(parent_message.root)
      else
        track_activity_for_ei(EngagementIndex::Activity::MESSAGE_USERS, {:context_place => params[:message][:src]})
        redirect_to_back_mark_or_default root_organization_path
      end
    else
      flash[:error] =  (@message.errors[:attachment_content_type].present? || @message.errors[:attachment_file_size].present?) ? @message.errors.full_messages.to_sentence.presence : "flash_message.message_flash.post_failure".translate
      @receiver = @message.receivers[0]
      if parent_message
        redirect_to_back_mark_or_default message_path(parent_message.root)
      else
        render :action => "new"
      end
    end
  rescue VirusError
    flash[:error] = "flash_message.message_flash.virus_present".translate
    if params[:message][:parent_id].present?
      redirect_to_back_mark_or_default message_path(parent_message.root)
    else
      @receiver = @message.receivers[0]
      render :action => "new"
    end
  end

  def index
    @messages_presenter = Messages::MessagesPresenter.new(wob_member, @current_organization, params.slice(:tab, :page, :search_filters).merge({html_request: !request.xhr?}))
    @my_filters = @messages_presenter.my_filters
  end

  def show
    @inbox = (params[:is_inbox] == 'true')
    back_link_text = @inbox ? "feature.messaging.back_link.inbox".translate : "feature.messaging.back_link.sent_items".translate
    back_link_tab  = @inbox ? MessageConstants::Tabs::INBOX : MessageConstants::Tabs::SENT
    back_link_path = messages_path( { tab: back_link_tab }.merge(permitted_filters_params))
    @back_link = { label: back_link_text, link: back_link_path }
    @open_reply = params[:reply].present?
    allow! exec: lambda { @message.root.thread_can_be_viewed?(wob_member) }
    @skip_rounded_white_box_for_content = true
  end

  def destroy
    allow! :exec => lambda { @message.can_be_deleted?(wob_member) }
    @message.mark_deleted!(wob_member)
    flash[:notice] = "flash_message.message_flash.deleted".translate
    if @message.root.thread_can_be_viewed?(wob_member)
      redirect_to_back_mark_or_default message_path(@message.root)
    else
      redirect_to messages_path
    end
  end

  private

  def message_params(action)
    params.require(:message).permit(Message::MASS_UPDATE_ATTRIBUTES[action])
  end

  def mark_siblings_as_read
    @message.root.mark_siblings_as_read(wob_member)
  end

  def fetch_message
    @message = AbstractMessage.find(params[:id])
    if @message.is_a?(Scrap)
      options = {:reply => params[:reply], :is_inbox => params[:is_inbox], :from_inbox => true, :root => @message.program.root}
      redirect_to scrap_path(@message, options)
    end
  end

  def validate_message
    valid_message = true
    if !@message.parent && current_user
      program = current_user.program
      @message.receivers.each do |receiver|
        valid_message &&= current_user.allowed_to_send_message?(receiver.user_in_program(program))
      end
    end
    valid_message
  end

  def set_member_id_for_newrelic
    NewRelic::Agent.add_custom_parameters 'Member_ID' => current_member.id if current_member.present?
  end

  def permitted_filters_params
    return {} if params[:filters_params].blank?

    params[:filters_params].permit(search_filters: [:date_range, :sender, :receiver, :search_content, status: [:read, :unread]]).to_h
  end
end