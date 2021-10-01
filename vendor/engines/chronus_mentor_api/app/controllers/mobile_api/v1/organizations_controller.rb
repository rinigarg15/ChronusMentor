class MobileApi::V1::OrganizationsController < MobileApi::V1::BasicController
  skip_before_action :require_program
  before_action Proc.new{ authenticate_user(false) }, :except => [:setup]

  def setup
    @programs = @current_organization.programs.published_programs.ordered.includes([:translations, :contact_admin_setting])
    @auth_configs = @current_organization.auth_configs
    @sso_base_url = new_session_url(host: @current_organization.domain, subdomain: @current_organization.subdomain, protocol: "http")
    render_success "organizations/index"
  end
end
