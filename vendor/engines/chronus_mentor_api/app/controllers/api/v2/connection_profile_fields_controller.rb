class Api::V2::ConnectionProfileFieldsController < Api::V2::BasicController
  before_action :build_presenter

  # GET /api/connection_profile_fields.json
  # GET /api/connection_profile_fields.xml
  def index
    result = @presenter.list(params)
    render_presenter_response(result, :connection_profiles)
  end

protected
  def build_presenter
    @presenter = Api::V2::ConnectionProfileFieldsPresenter.new(@current_program)
  end
end
