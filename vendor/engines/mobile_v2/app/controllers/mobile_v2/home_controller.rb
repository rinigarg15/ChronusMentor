class MobileV2::HomeController < ApplicationController
  layout "mobile_v2/application"
  allow exec: :is_mobile_app?, except: [:validate_member, :finish_mobile_app_login_experiment]
  allow exec: :check_api_access?, only: [:validate_member]
  skip_before_action :login_required_in_program, :require_program, :require_organization, :handle_secondary_url
  skip_before_action :set_locale_from_cookie_or_member
  skip_before_action :verify_authenticity_token, only: [:validate_member, :finish_mobile_app_login_experiment]
  before_action :set_locale_from_cookie
  before_action :set_uniq_token_cookie_value, only: [:verify_organization, :global_member_search]
  before_action :set_show_program_form, only: [:verify_organization]

  def verify_organization
    set_updated_cookie(params)
    if @redirect_url
      redirect_to @redirect_url and return unless params[:open_url]
    else
      @experiment = chronus_ab_test_only_use_cookie(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true)
    end
    handle_open_url(params)
  end

  def validate_organization
    if @current_organization.present?
      status = "ok"
      url = @current_organization.url
      hostnames = @current_organization.hostnames
    end
    render json: { status: status, valid_program: @current_program.present?, organization_url: url, default_hosts: hostnames}
  end

  def fakedoor
    @fakedoor_gtac_info_string = true
    @disable_footer = true
  end

  def global_member_search
    # This action should be called only from the production server
    GlobalMemberSearch.delay(queue: DjQueues::HIGH_PRIORITY).search(params[:email], @uniq_token)
  end

  def validate_member
    members = Member.where(email: params[:email])
    if members.present?
      GlobalMemberSearch.configure_login_token_and_email(members, params[:uniq_token])
      render json: { status: "ok"}
    end
  end

  def finish_mobile_app_login_experiment
    finished_chronus_ab_test_only_use_cookie(ProgramAbTest::Experiment::MOBILE_APP_LOGIN_WORKFLOW, true, true)
    head :ok
  end

  private

  def check_api_access?
    return false unless params[:global_member_search_api_key].present?
    encrypted_api_key = Digest::SHA1.hexdigest(params[:global_member_search_api_key])
    encrypted_api_key == APP_CONFIG[:global_member_search_encrypted_api_key]
  end

  def set_updated_cookie(params)
    org_url_cookie_name = MobileV2Constants::ORGANIZATION_SETUP_COOKIE
    if params[:edit]
      @change_program_url = true
      cookies.delete(org_url_cookie_name)
    elsif params[:open_url]
      cookies.delete(org_url_cookie_name)
      uri = URI.parse(params[:open_url])
      new_query_ar = URI.decode_www_form(uri.query || '') << ["cjs_from_select_org", "true"]
      uri.query = URI.encode_www_form(new_query_ar)
      uri = uri.to_s
      @redirect_url = uri
    else
      @redirect_url = (cookies[org_url_cookie_name] + "?last_visited_program=true&cjs_from_select_org=true") if cookies[org_url_cookie_name].present?
    end
  end

  def handle_open_url(params)
    if params[:open_url].present?
      @disable_header = true
      @disable_footer = true
    end
  end

  def set_locale_from_cookie
    current_locale = (cookies[:current_locale].present? ? cookies[:current_locale] : I18n.default_locale.to_s).to_sym
    I18n.locale =  current_locale
  end

  def set_uniq_token_cookie_value
    @uniq_token = cookies[:uniq_token]
  end

  def set_show_program_form
    @show_program_form = params[:show_program_form].to_s.to_boolean
  end
end