class AddMentorProfilePreferencePermission < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Permission.count > 0
        Permission.create_default_permissions
        Role.where(name: RoleConstants::STUDENT_NAME).find_each do |role|
          role.add_permission("ignore_and_mark_favorite")
        end
      end
    end
  end
end