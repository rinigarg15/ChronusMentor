class MobileApi::V1::ResourcesController < MobileApi::V1::BasicController
  before_action :authenticate_user
  before_action :build_presenter
  respond_to :json

  def index
    result = @presenter.list(params.merge(acting_user: current_user))
    render_presenter_response(result)
  end

  def show
    result = @presenter.find(params[:id], params.merge(acting_user: current_user))
    render_presenter_response(result)
  end

  protected

  def build_presenter
    @presenter = MobileApi::V1::ResourcesPresenter.new(@current_program)
  end
end