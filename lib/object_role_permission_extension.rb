module ObjectRolePermissionExtension
  extend ActiveSupport::Concern

  class_methods do
    def acts_as_object_role_permission_authorizable
      has_many :object_role_permissions, dependent: :destroy, as: :ref_obj
      has_many :object_permissions, through: :object_role_permissions

      # We have used ::ObjectPermission intentionally
      # https://stackoverflow.com/questions/29636334/a-copy-of-xxx-has-been-removed-from-the-module-tree-but-is-still-active
      ::ObjectPermission::MentoringModel::PERMISSIONS.each do |permission_name|
        define_method("can_#{permission_name}?") do |roles_in|
          permission = ObjectPermission.find_by!(name: permission_name)
          roles = self.sanitize_roles_input(roles_in)
          self.object_role_permissions.select{ |orp| (orp.object_permission_id == permission.id) && roles.map(&:id).include?(orp.role_id)}.any?
        end

        define_method("allow_#{permission_name}!") do |roles_in|
          permission = ObjectPermission.find_by!(name: permission_name)
          roles = self.sanitize_roles_input(roles_in)
          roles.each do |role|
            self.object_role_permissions.find_or_create_by(role_id: role.id, object_permission_id: permission.id)
          end
          true
        end

        define_method("deny_#{permission_name}!") do |roles_in|
          permission = ObjectPermission.find_by!(name: permission_name)
          roles = self.sanitize_roles_input(roles_in)
          self.object_role_permissions.where(role_id: roles.map(&:id), object_permission_id: permission.id).destroy_all
        end
      end
    end
  end

  def sanitize_roles_input(roles_in)
    roles_in.is_a?(Role) ? [roles_in] : roles_in
  end

  def copy_object_role_permissions_from!(obj, options = {})
    role_mapping = get_role_mapping(obj, options)
    ObjectPermission::MentoringModel::PERMISSIONS.each do |permission_name|
      role_mapping.each do |from_role, to_role|
        self.send("#{ obj.send("can_#{permission_name}?", from_role) ? "allow" : "deny" }_#{permission_name}!", to_role)
      end
    end
  end

  private

  def get_role_mapping(obj, options)
    roles = options[:roles] || obj.roles
    options[:role_mapping].presence || roles.inject({}) do |role_mapping, role|
      role_mapping[role] = role
      role_mapping
    end
  end
end