class ResourcePublicationImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["program_id", "resource_id", "admin_view_id"]

  AssociatedImporters = ["RoleResourceImporter"]

  AssociatedModel = "ResourcePublication"
  FileName = 'resource_publication'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_resource_id(resource_id, obj)
    obj.resource_id = self.solution_pack.id_mappings[ResourceImporter::AssociatedModel][resource_id.to_i]
  end

  def process_admin_view_id(admin_view_id, obj)
    obj.admin_view_id = self.solution_pack.id_mappings[AdminViewImporter::AssociatedModel][admin_view_id.to_i]
  end
end