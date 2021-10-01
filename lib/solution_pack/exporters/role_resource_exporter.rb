class RoleResourceExporter < SolutionPack::Exporter

  AssociatedExporters = ["RoleExporter"]
  FileName = "role_resource"
  AssociatedModel = "RoleResource"

  def initialize(program, parent_exporter)
    self.objs = program.roles.collect(&:role_resources).flatten
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end