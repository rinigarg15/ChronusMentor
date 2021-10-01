class ObjectPermissionExporter < SolutionPack::Exporter

  AssociatedExporters = ["ObjectRolePermissionExporter"]
  FileName = 'object_permission'
  AssociatedModel = "ObjectPermission"

  def initialize(program, parent_exporter)
    if(parent_exporter.class == MentoringModelExporter)
      self.objs = ObjectPermission.all
    end

    self.program = program
    self.parent_exporter = parent_exporter
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end