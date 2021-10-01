class AddMeetingPreferencePermission< ActiveRecord::Migration[4.2]
  def change
    if Permission.count > 0
      Permission.create_default_permissions
      Role.where(name: RoleConstants::STUDENT_NAME).find_each do |role|
        role.add_permission("set_meeting_preference")
      end
    end
  end
end