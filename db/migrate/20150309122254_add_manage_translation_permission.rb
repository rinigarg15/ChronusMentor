class AddManageTranslationPermission< ActiveRecord::Migration[4.2]
  def change
    if Permission.count > 0
      Permission.create_default_permissions
      Role.administrative.each do |role|
        role.add_permission('manage_translations')
      end
    end
  end
end
