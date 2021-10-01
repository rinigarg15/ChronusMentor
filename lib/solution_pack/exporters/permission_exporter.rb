class PermissionExporter < SolutionPack::Exporter

  FileName = 'permission'
  AssociatedModel = "Permission"

  def initialize(program, parent_exporter)
    self.objs = []
    if parent_exporter.class == RolePermissionExporter
      self.objs = parent_exporter.objs.collect(&:permission).uniq
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end