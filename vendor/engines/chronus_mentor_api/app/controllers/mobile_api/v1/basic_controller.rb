class MobileApi::V1::BasicController < ApplicationController
  include AuthenticationUtils
  # skip_action_callbacks_for_mobile_api should be on top as any before filters above or before this will not be executed
  skip_action_callbacks_for_mobile_api

  skip_all_action_callbacks only: :catch_all_options
  before_action :set_cors
  before_action :validate_mobile_env  # to prevent requests across different environments
  before_action :reset_session
  before_action :set_client_versions
  after_action :update_mobile_last_seen_at
  respond_to :json

  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS#Preflighted_requests
  def catch_all_options
    response.headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET'
    head :ok
  end

protected

  def update_mobile_last_seen_at
    update_last_seen_at if @current_user.present?
  end

  def render_response(res)
    status = res[:status] || 200
    embed_default_params(res)
    respond_to do |format|
      format.json { render json: res[:data], status: status }
    end
  end

  def render_error_response
    render_response(data: {success: false}, status: 404)
  end

  def render_presenter_response(result)
    render_response({
      data:     result[:success] ? result[:data] : result[:errors],
      status:   result[:success] ? 200 : 404
    })
  end

  def render_errors(errors, status = 404, options = {})
    render 'mobile_api/v1/errors', {locals: {errors: errors}, status: status}.merge(options)
  end

  def render_success(partial, local_params = {})
    render "mobile_api/v1/#{partial}", {locals: get_jbuilder_defaults.merge(local_params), status: 200}
  end

  def set_locale_and_terminology_helpers
    set_locale_from_cookie_or_member
    set_terminology_helpers
  end

private

  def set_cors
    # TODO: There is definitely a security risk by setting Access-Control-Allow-Origin "*"
    # We should have a white-list and be using the https://github.com/cyu/rack-cors, which binds this at the middleware level
    # References: http://bit.ly/1mfr6zy | http://bit.ly/1w0ufnM | http://bit.ly/VXuKUZ
    response.headers["Access-Control-Allow-Origin"] = '*'
    response.headers["Access-Control-Expose-Headers"] = "CHRONUS-NATIVE-VERSION,CHRONUS-HTML-VERSION"
  end

  def set_client_versions
    native_version = File.read(File.join(Rails.root, APP_CONFIG[:native_version_path])).strip
    html_version = File.read(File.join(Rails.root, APP_CONFIG[:html_version_path])).strip
    ## Http Response Headers naming convention: http://stackoverflow.com/questions/3561381/custom-http-headers-naming-conventions
    response.headers["CHRONUS-NATIVE-VERSION"] = native_version
    response.headers["CHRONUS-HTML-VERSION"] = html_version
  end

  def embed_default_params(result)
    default_params = build_common_hash
    if default_params.present?
      result[:data].merge!(default_params)
    end
  end

  def get_jbuilder_defaults
    build_common_hash
  end

  def build_common_hash
    common_parameters = MobileApi::CommonParameters.new(@current_organization, @current_member, @current_program, @current_user)
    common_parameters.build_hash(params[:client_md5], self)
  end

  def validate_mobile_env
    api_env = get_mobile_api_env
    mobile_env = request.params["env"]
    unless mobile_env.nil? || api_env == mobile_env
      render_response(data: {success: false, invalid_env: true}, status: 403) and return false
    end
    return true
  end

  def get_mobile_api_env
    if Rails.env.production? || Rails.env.productioneu? || Rails.env.generalelectric? || Rails.env.veteransadmin? || Rails.env.nch? || Rails.env.demo?
      "production"
    else
      Rails.env
    end
  end
end
