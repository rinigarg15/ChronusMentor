class RolePermissionImporter < SolutionPack::Importer

  NoImportAttributes = []
  CustomAttributes = ["role_id", "permission_id"]

  AssociatedModel = "RolePermission"
  FileName = 'role_permission'

  def initialize(parent_importer)
    super parent_importer
    invite_permission_names = self.solution_pack.program.roles.map{|role| "invite_#{role.name.pluralize}"}
    exisiting_role_permissions = self.solution_pack.program.roles_without_admin_role.collect(&:role_permissions).flatten.select{|rp| invite_permission_names.include?(rp.permission.name)}
    exisiting_role_permissions.each do |permission|
      permission.destroy
    end
  end

  def process_role_id(role_id, obj)
    obj.role_id = self.solution_pack.id_mappings[RoleImporter::AssociatedModel][role_id.to_i]
  end

  def process_permission_id(permission_id, obj)
    obj.permission_id = self.solution_pack.id_mappings[PermissionImporter::AssociatedModel][permission_id.to_i]
  end

  def handle_object_creation(obj, old_id, column_names, row)
    role = self.solution_pack.program.roles.find(obj.role_id)
    existing_obj = role.role_permissions.where(:permission_id => obj.permission_id).first if role.present?
    if existing_obj.present?
      return existing_obj
    else
      obj.save!
      return obj
    end
  end
end