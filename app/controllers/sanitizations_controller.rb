class SanitizationsController < ApplicationController
  include SanitizeAllowScriptAccess
  include SanitizationsHelper
  skip_before_action :login_required_in_program, :require_program
  before_action :login_required_at_current_level

  def compare_content_before_and_after_sanitize
    ret = ChronusSanitization::Utils.vulnerable_content?(@current_organization, params[:content])
    @vulnerable = ret[:vulnerable]
    @original_content = ret[:original_content]
    @sanitized_content = ret[:sanitized_content]
    render json: {
      sanitized_content: @sanitized_content,
      diff: (@vulnerable ? format_insecure_content(@original_content, @sanitized_content).gsub(/\n/,"").html_safe : '')
    }
  end

  def preview_sanitized_content
    original_content = params[:content].to_s
    is_admin = (current_user ? current_user.is_admin? : (current_member ? current_member.admin? : false))
    if is_admin
      # For admins sanitization is not needed
      @sanitized_content = original_content.html_safe
    else
      @sanitized_content = chronus_sanitize(original_content, sanitization_version: @current_organization.security_setting.sanitization_version)
    end
  end
end