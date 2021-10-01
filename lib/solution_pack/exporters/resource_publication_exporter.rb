class ResourcePublicationExporter < SolutionPack::Exporter

  AssociatedExporters = ["RoleResourceExporter"]
  FileName = "resource_publication"
  AssociatedModel = "ResourcePublication"

  def initialize(program, parent_exporter)
    self.objs = program.resource_publications
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end