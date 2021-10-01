class AddingMentoringModelBasePermissions< ActiveRecord::Migration[4.2]
  def change
    ObjectPermission.create_default_permissions
  end
end
