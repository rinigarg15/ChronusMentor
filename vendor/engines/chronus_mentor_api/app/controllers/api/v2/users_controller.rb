class Api::V2::UsersController < Api::V2::BasicController
  before_action :build_presenter

  # GET /api/users.json
  # GET /api/users.xml
  def index
    result = @presenter.list(params)
    render_presenter_response(result, :users)
  end

  # POST /api/users.json
  # POST /api/users.xml
  def create
    result = @presenter.create(params.merge(acting_user: current_user))
    render_presenter_response(result, :user)
  end

  #PUT /api/users/update_status
  def update_status
    result = @presenter.update_status(params, current_member)
    render_presenter_response(result, :user)
  end


  # DELETE /api/users/1.json
  # DELETE /api/users/1.xml
  def destroy
    result = @presenter.destroy(params[:id])
    render_presenter_response(result, :user)
  end

protected
  def build_presenter
    @presenter = Api::V2::UsersPresenter.new(@current_program, @current_organization)
  end
end
