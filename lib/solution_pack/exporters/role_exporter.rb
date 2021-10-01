class RoleExporter < SolutionPack::Exporter

  AssociatedExporters = ["CustomizedTermExporter", "RolePermissionExporter"]
  FileName = 'role'
  AssociatedModel = "Role"

  def initialize(program, parent_exporter)
    self.objs = program.roles
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end