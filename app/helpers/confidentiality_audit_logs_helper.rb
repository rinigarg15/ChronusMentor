module ConfidentialityAuditLogsHelper
  def get_mentor_for_group(audit_log)
    safe_join([audit_log.group.mentors.collect {|mentor| link_to_user mentor }].flatten, COMMON_SEPARATOR)
  end

  def get_mentees_for_group(audit_log)
    safe_join([audit_log.group.students.collect {|mentee| link_to_user mentee }].flatten, COMMON_SEPARATOR)
  end
end