class Api::V2::MembersController < Api::V2::BasicController
  before_action :build_presenter
  skip_before_action :require_program

  # GET /api/users.json
  # GET /api/users.xml
  def index
    params.delete(:profile)
    params.delete(:updated_after)
    params.merge!(members_list: true)
    result = @presenter.list(params)
    render_presenter_response(result, :users)
  end

  def profile_updates
    params.delete(:email)
    params.delete(:created_after)
    params.merge!(profile: 1)
    result = @presenter.list(params)
    render_presenter_response(result, :users)
  end

  def update
    result = @presenter.update(params)
    render_presenter_response(result, :user)
  end

  # POST /api/members
  def create
    result = @presenter.create(params)
    render_presenter_response(result, :user)
  end

  def destroy
    result = @presenter.destroy(params)
    render_presenter_response(result, :user)
  end

  def update_status
    result = @presenter.update_status(params, current_member)
    render_presenter_response(result, :user)
  end

  def get_uuid
    result = @presenter.get_uuid(params)
    render_presenter_response(result, :uuid)  
  end

  # GET /api/members/1.json
  # GET /api/members/1.xml
  def show
    result = @presenter.find(params[:id], params)
    render_presenter_response(result, :user)
  end

  protected
  def build_presenter
    @presenter = Api::V2::MembersPresenter.new(nil, @current_organization)
  end
end