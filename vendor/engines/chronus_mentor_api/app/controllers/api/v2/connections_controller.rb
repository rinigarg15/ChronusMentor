class Api::V2::ConnectionsController < Api::V2::BasicController
  before_action :build_presenter

  # GET /api/connections.json
  # GET /api/connections.xml
  def index
    result = @presenter.list(params)
    render_presenter_response(result, :connections)
  end

  # GET /api/connections/1.json
  # GET /api/connections/1.xml
  def show
    result = @presenter.find(params[:id], params)
    render_presenter_response(result, :connection)
  end

  # POST /api/connections.json
  # POST /api/connections.xml
  def create
    result = @presenter.create(params.merge(acting_user: current_user))
    render_presenter_response(result, :connection)
  end

  # PUT /api/connections/1.json
  # PUT /api/connections/1.xml
  def update
    result = @presenter.update(params[:id], params.merge(acting_user: current_user))
    render_presenter_response(result, :connection)
  end

  # DELETE /api/connections/1.json
  # DELETE /api/connections/1.xml
  def destroy
    result = @presenter.destroy(params[:id])
    render_presenter_response(result, :connection)
  end

protected
  def build_presenter
    @presenter = Api::V2::ConnectionsPresenter.new(@current_program)
  end
end
