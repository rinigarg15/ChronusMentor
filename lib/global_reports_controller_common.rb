module GlobalReportsControllerCommon
  def can_access_global_reports?
    @current_organization&.global_reports_v3_applicable?(accessing_as_super_admin: super_console?, member: wob_member)
  end
end