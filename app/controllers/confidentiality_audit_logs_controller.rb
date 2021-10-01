class ConfidentialityAuditLogsController < ApplicationController
  allow :user => :can_view_audit_logs?
  allow :exec => :check_program_has_ongoing_mentoring_enabled
  allow :exec => :audit_logs_enabled?

  def index
    @audit_logs = @current_program.confidentiality_audit_logs.paginate :page => params[:page]
  end

  def new
    @back_link = {:label => _Mentoring_Connections, :link => groups_path}
    @group = @current_program.groups.find(params[:group_id])
    @latest_log = current_user.confidentiality_audit_logs.find_by(group_id: @group.id)
    if !@latest_log.blank? && @latest_log.created_at > 5.minutes.ago
      redirect_to group_path(@group)
      return
    end
    @confidentiality_audit_log = @current_program.confidentiality_audit_logs.new
    @confidentiality_audit_log.group = @group
  end
  
  def create
    @group = @current_program.groups.find(params[:group_id])
    @latest_log = current_user.confidentiality_audit_logs.find_by(group_id: @group.id)
    if !@latest_log.blank? && @latest_log.created_at > 5.minutes.ago
      redirect_to group_path(@group)
    else
      @confidentiality_audit_log = @current_program.confidentiality_audit_logs.new(confidentiality_audit_log_params(:create))
      @confidentiality_audit_log.user = current_user;
      @confidentiality_audit_log.group = @group
      if @confidentiality_audit_log.save
        redirect_to group_path(@group)
      else
        flash[:error] = "flash_message.group_flash.reason_not_valid".translate
        redirect_to new_confidentiality_audit_log_path(:group_id => @group.id)
      end
    end
  end

  private

  def confidentiality_audit_log_params(action)
    params[:confidentiality_audit_log].present? ? params[:confidentiality_audit_log].permit(ConfidentialityAuditLog::MASS_UPDATE_ATTRIBUTES[action]) : {}
  end

  def audit_logs_enabled?
    @current_program.confidentiality_audit_logs_enabled?
  end
end
