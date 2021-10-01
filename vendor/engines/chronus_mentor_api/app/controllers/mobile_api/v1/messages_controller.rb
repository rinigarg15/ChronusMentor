class MobileApi::V1::MessagesController < MobileApi::V1::BasicController
  skip_before_action :require_program
  before_action { |controller| controller.authenticate_user(false) }
  before_action :fetch_message, :only => [:show, :destroy]
  after_action :mark_tree_read, :only => [:show]
  respond_to :json

  # TODO :: Have a allow exec execption for message new and create
  def new
    @receiver = @current_program.all_users.includes(:member).find(params[:receiver_id])
    render_success("messages/new")
  end

  def create
    # will handle reply for all types of messages["Message", "AdminMessage", "Scrap"]
    # But will create only messages of type "Message"
    if params[:message][:parent_id].present?
      parent_message = AbstractMessage.find(params[:message][:parent_id])
      @message = parent_message.build_reply(@current_member)
      @message.content = params[:message][:content]
    else
      @message = @current_organization.messages.build
      @message.attributes = params[:message].pick(:subject, :content, :receiver_ids)
    end
    @message.sender = @current_member
    @message.attachment = params[:message][:attachment]
    if @message.save
      render_presenter_response({data: {id: @message.id}, success: true})
    else
      render_errors(@message.errors.full_messages)
    end
  end

  def index
    @messages_presenter = Messages::MessagesPresenter.new(current_member, @current_organization, params.slice(:tab, :page, :search_filters))
    render_success("messages/index")
  end


  def show
    if @message.can_be_viewed?(@current_member)
      render_success("messages/show")
    else
      render_error_response
    end
  end

  def destroy
    if @message.can_be_replied_or_deleted?(@current_member)
      @message.mark_deleted!(@current_member)
      render_presenter_response({data: {id: @message.id}, success: true})
    else
      render_error_response
    end
  end

  private

  def mark_tree_read
    @message.mark_tree_as_read!(@current_member) if @message.present?
  end

  def fetch_message
    @message = AbstractMessage.find_by(id: params[:id])
    unless @message.present?
      render_errors([ApiConstants::CommonErrors::ENTITY_NOT_FOUND % {entity: Message.name, attribute: :id, value: params[:id]}], 404) and return
    end
  end

end