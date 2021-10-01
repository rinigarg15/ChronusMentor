module SalesDemo
  class ObjectRolePermissionPopulator < BasePopulator
    REQUIRED_FIELDS = ObjectRolePermission.attribute_names.map(&:to_sym) - [:id, :role_id, :object_permission_id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :object_role_permissions)
    end

    def copy_data
      self.reference.each do |ref_object|
        ObjectRolePermission.new.tap do |object_role_permission|
          assign_data(object_role_permission, ref_object)
          object_role_permission.ref_obj_type = "Group"
          object_role_permission.ref_obj_id = master_populator.referer_hash[:group][ref_object.ref_obj_id]
          program_id = Group.where(:id => master_populator.referer_hash[:group][ref_object.ref_obj_id]).pluck(:program_id).first
          object_role_permission.role = Role.where(:name => ref_object.role_name, :program_id => program_id).first
          object_role_permission.object_permission = ObjectPermission.find_by(name: ref_object.object_permission_name)
          object_role_permission.save_without_timestamping!
        end
      end
    end


    DUMPING_FIELDS = ObjectRolePermission.attribute_names.map(&:to_sym) - [:id, :role_id, :object_permission_id] + [:role_name, :object_permission_name]
    def self.dump_data(users)
      return users.collect do |user|
        DUMPING_FIELDS.inject({}) do |hash_map, field|
          value = user.send(field)
          hash_map[field] = value.is_a?(Array) ?  Marshal.dump(value) : value
          hash_map
        end
      end
    end
  end
end