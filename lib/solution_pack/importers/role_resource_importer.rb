class RoleResourceImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["role_id", "resource_publication_id"]

  AssociatedImporters = []

  AssociatedModel = "RoleResource"
  FileName = 'role_resource'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_role_id(role_id, obj)
    obj.role_id = self.solution_pack.id_mappings[RoleImporter::AssociatedModel][role_id.to_i]
  end

  def process_resource_publication_id(resource_publication_id, obj)
    obj.resource_publication_id = self.solution_pack.id_mappings[ResourcePublicationImporter::AssociatedModel][resource_publication_id.to_i]
  end
end