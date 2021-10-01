class RemoveConfidentialityLogsFeature< ActiveRecord::Migration[4.2]
  def change
    puts "Removing the Confidentiality Audit Logs as a feature."
    puts "=========================================="
    feature_audit_logs = Feature.find_by(name: "confidentiality_audit_logs")
    unless feature_audit_logs.nil?
      feature_audit_logs.destroy
    end
  end
end
