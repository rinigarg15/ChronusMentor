class Api::V2::ProfileFieldsController < Api::V2::BasicController
  before_action :build_presenter
  skip_before_action :require_program

  # GET /api/connection_profile_fields.json
  # GET /api/connection_profile_fields.xml
  def index
    result = @presenter.list(params)
    render_presenter_response(result, :profile_fields)
  end

protected
  def build_presenter
    @presenter = Api::V2::ProfileFieldsPresenter.new(nil, @current_organization)
  end
end
