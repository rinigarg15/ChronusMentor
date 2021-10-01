class MobileApi::V1::AdminMessagesController < MobileApi::V1::BasicController
  before_action :require_program
  before_action :validate_user_and_set_locale, :only => :create

  # Handled for contacting admin at track level only
  def create
    @admin_message = @current_program.admin_messages.build
    if current_member
      @admin_message.attributes = params[:admin_message].pick(:subject, :content)
      @admin_message.sender = current_member
    else
      @admin_message.attributes = params[:admin_message].pick(:subject, :content, :sender_name, :sender_email)
    end
    # This is the case when a user is trying to contact admin - So there will be no receivers just a message_receiver with no member
    @admin_message.message_receivers.build
    if @admin_message.save
      render_response(data: {success: true}, status: 200)
    else
      render_response(data: {success: false, errors: @admin_message.errors.full_messages}, status: 404)
    end
  end

  private

  def validate_user_and_set_locale(program_context = true)
    if params[:mobile_auth_token].present?
      authenticate_user(program_context) 
    else
      set_locale_and_terminology_helpers
    end
  end
end