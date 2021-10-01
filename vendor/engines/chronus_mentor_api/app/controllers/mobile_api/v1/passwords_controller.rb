class MobileApi::V1::PasswordsController < MobileApi::V1::BasicController
  skip_before_action :require_program
  before_action :set_locale_and_terminology_helpers
  respond_to :json

  def create
    member = @current_organization.members.find_by(email: params[:email])
    password = Password.new(member: member)
    if password.save
      ChronusMailer.forgot_password(password, @current_organization).deliver_now
    end
    render_response(data: {success: true}, status: 200)
  end
end