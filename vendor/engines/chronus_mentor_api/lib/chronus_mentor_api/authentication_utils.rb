module AuthenticationUtils
  def self.included(controller)
    controller.send :include, CommonInclusions
  end

  module CommonInclusions
    def authenticate_user(program_context = true)
      if params[:mobile_auth_token].present?
        auth_chain = @current_organization.members.active.joins(:mobile_devices).where(mobile_devices: {mobile_auth_token: params[:mobile_auth_token]})
        if auth_chain.exists?
          self.current_member = auth_chain.first
        end
      end
      # Mobile application is incapable of handling cookies
      # Hence, set the locale only after member is authenticated
      # Explicitly call the filter set_locale_and_terminology_helpers in case authenticate_user filter is not called
      set_locale_and_terminology_helpers
      level_context = program_context ? logged_in_program? : logged_in_organization?
      render_response(data: {success: false, invalid_auth_token: true}, xml_root: :errors, status: 403) unless level_context
    end
  end
end