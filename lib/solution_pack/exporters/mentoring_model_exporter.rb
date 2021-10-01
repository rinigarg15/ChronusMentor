class MentoringModelExporter < SolutionPack::Exporter

  AssociatedExporters = ["MentoringModelTemplatesExporter", "MentoringModelLinkExporter", "ObjectPermissionExporter"]
  FileName = 'mentoring_model'
  AssociatedModel = "MentoringModel"

  def initialize(program, parent_exporter)
    self.objs = program.mentoring_models
    self.program = program
    self.parent_exporter = parent_exporter
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end