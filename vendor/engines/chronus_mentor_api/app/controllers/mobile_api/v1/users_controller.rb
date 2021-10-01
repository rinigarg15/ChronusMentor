class MobileApi::V1::UsersController < MobileApi::V1::BasicController
  before_action :authenticate_user
  before_action :build_presenter

  def index
    result = @presenter.list(current_user, params)
    render_presenter_response(result)
  end

  def show
    result = @presenter.find(current_user, params)
    render_presenter_response(result)
  end

  def dashboard
    result = @presenter.dashboard(current_user, params)
    render_presenter_response(result)
  end

protected
  def build_presenter
    @presenter = MobileApi::V1::UsersPresenter.new(@current_program)
  end
end
