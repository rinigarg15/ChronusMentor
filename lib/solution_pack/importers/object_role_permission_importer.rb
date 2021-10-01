class ObjectRolePermissionImporter < SolutionPack::Importer

  NoImportAttributes = ["updated_at", "created_at"]
  CustomAttributes = ["ref_obj_id", "role_id"]

  AssociatedModel = "ObjectRolePermission"
  FileName = 'object_role_permission'

  def initialize(parent_importer)
    super parent_importer
  end

  def preprocess_import
    destroy_object_role_permissions
  end

  def destroy_object_role_permissions
    self.solution_pack.program.mentoring_models.each do |mentoring_model|
      mentoring_model.object_role_permissions.destroy_all
    end
  end

  def process_ref_obj_id(ref_obj_id, obj)
    obj.ref_obj_id = self.solution_pack.id_mappings[MentoringModelImporter::AssociatedModel][ref_obj_id.to_i]
  end

  def process_role_id(role_id, obj)
    obj.role_id = self.solution_pack.id_mappings[RoleImporter::AssociatedModel][role_id.to_i]
  end
end