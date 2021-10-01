class ObjectRolePermissionExporter < SolutionPack::Exporter

  FileName = 'object_role_permission'
  AssociatedModel = "ObjectRolePermission"

  def initialize(program, parent_exporter)
    if(parent_exporter.class == ObjectPermissionExporter)
      mentoring_model_ids = program.mentoring_models.collect(&:id)
      self.objs = program.mentoring_models.collect(&:object_role_permissions).flatten
    end

    self.program = program
    self.parent_exporter = parent_exporter
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end