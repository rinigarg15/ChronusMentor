class ConfidentialityAuditLogPopulator < PopulatorTask

  def patch(options = {})
    return unless @program.engagement_enabled?
    group_ids = @program.groups.pluck(:id)
    confidentiality_audit_logs_hsh = get_children_hash(@program, @options[:args]["model"]||@node, @foreign_key, group_ids)
    process_patch(group_ids, confidentiality_audit_logs_hsh)
  end

  def add_confidentiality_audit_logs(group_ids, count, options = {})
    self.class.benchmark_wrapper "confidentiality logs" do
      program = options[:program]
      temp_group_ids = group_ids * count
      admin_user_ids = program.admin_users.pluck(:id)
      temp_admin_user_ids = admin_user_ids.dup
      ConfidentialityAuditLog.populate(count * group_ids.count, :per_query => 10_000) do |confidentiality_audit_log|
        temp_admin_user_ids = admin_user_ids.dup if temp_admin_user_ids.blank?
        confidentiality_audit_log.program_id = program.id
        confidentiality_audit_log.group_id = temp_group_ids.shift
        confidentiality_audit_log.user_id = temp_admin_user_ids.shift
        confidentiality_audit_log.reason = Populator.sentences(1..2)
        self.dot
      end
      self.class.display_populated_count(group_ids.size * count, "confidentiality logs")
    end
  end

  def remove_confidentiality_audit_logs(group_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Confidentiality Audit Log................" do
      program = options[:program]
      confidentiality_audit_log_ids = program.confidentiality_audit_logs.where(:group_id => group_ids).select([:id, :group_id]).group_by(&:group_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      program.confidentiality_audit_logs.where(:id => confidentiality_audit_log_ids).destroy_all
      self.class.display_deleted_count(group_ids.size * count, "confidentiality logs")
    end
  end
end