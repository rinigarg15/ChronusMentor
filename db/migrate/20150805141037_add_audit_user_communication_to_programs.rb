class AddAuditUserCommunicationToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :audit_user_communication, :boolean, default: false
  end
end
