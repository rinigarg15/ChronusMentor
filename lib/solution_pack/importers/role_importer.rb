class RoleImporter < SolutionPack::Importer

  NoImportAttributes = ["updated_at", "created_at"]
  CustomAttributes = ["program_id"]

  AssociatedImporters = ["PermissionImporter", "RolePermissionImporter", "CustomizedTermImporter"]

  AssociatedModel = "Role"
  FileName = 'role'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def handle_object_creation(obj, old_id, column_names, row)
    name_column_index = column_names.index('name')
    existing_obj = self.solution_pack.program.roles.where(name: row[name_column_index]).first
    if existing_obj.present?
      existing_obj.membership_request = obj.membership_request
      existing_obj.join_directly = obj.join_directly
      existing_obj.join_directly_only_with_sso = obj.join_directly_only_with_sso
      existing_obj.invitation = obj.invitation
      existing_obj.eligibility_rules = obj.eligibility_rules
      existing_obj.slot_config = obj.slot_config
      existing_obj.max_connections_limit = obj.max_connections_limit
      existing_obj.save!
      return existing_obj
    else
      obj.save!
      return obj
    end
  end
end