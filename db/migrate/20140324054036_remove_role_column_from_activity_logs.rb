class RemoveRoleColumnFromActivityLogs< ActiveRecord::Migration[4.2]
  def change
    role_mapping = {
      0 => [RoleConstants::MENTOR_NAME],
      1 => [RoleConstants::STUDENT_NAME],
      2 => [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]
    }
    ActiveRecord::Base.transaction do
      ActivityLog.includes(program: :roles).each do |activity_log|
          activity_log.role_names = role_mapping[activity_log.role]
          activity_log.save!
      end
    end
    remove_column :activity_logs, :role
  end
end
