class Api::V2::BasicController < ApplicationController
  skip_action_callbacks_for_api
  before_action :set_api_dj_priority
  before_action :set_default_response_format, :login_for_api
  before_action :can_access_api?

  respond_to :xml, :json

  ALLOWED_FORMATS = ["json", "xml"]

protected
  def login_for_api
    if params[:api_key].present?
      auth_chain = @current_organization.members.active.where(api_key: params[:api_key])
      self.current_member = auth_chain.first if auth_chain.exists?
    end
    render_response(data: [ApiConstants::AUTHORIZATION_KEY_ERROR], xml_root: :errors, status: 403) unless logged_in_at_current_level?
  end

  def render_response(response)
    status = response[:status] || 200
    respond_to do |format|
      format.json { render json: response[:data], status: status }
      format.xml  { render xml:  response[:data], root: response[:xml_root], status: status }
    end
  end

  def render_presenter_response(result, xml_root)
    render_response({
      data:     result[:success] ? result[:data] : result[:errors],
      xml_root: result[:success] ? xml_root : :errors,
      status:   result[:success] ? 200 : 404
    })
  end

  def can_access_api?
    render_response(data: [ApiConstants::AUTHORIZATION_KEY_ERROR], xml_root: :errors, status: 403) unless current_member.admin? ? true : (current_user.present? && current_user.is_admin?)
  end

  def set_default_response_format
    request.format = :json unless ALLOWED_FORMATS.include?(params[:format])
  end
end
