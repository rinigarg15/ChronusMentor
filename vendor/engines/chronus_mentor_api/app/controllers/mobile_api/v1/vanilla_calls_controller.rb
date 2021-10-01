class MobileApi::V1::VanillaCallsController < MobileApi::V1::BasicController
  # Not skipping filters :set_client_versions, :load_current_organization
  skip_before_action :require_program, :require_organization, :load_current_root, :load_current_program, :login_required_in_program, :configure_program_tabs, raise: false

  respond_to :json

  def index
    render_success('vanilla_calls/index')
  end

end