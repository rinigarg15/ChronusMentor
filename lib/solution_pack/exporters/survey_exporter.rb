class SurveyExporter < SolutionPack::Exporter

  AssociatedExporters = ["SurveyQuestionExporter", "RoleReferenceExporter"]
  FileName = 'survey'
  AssociatedModel = "Survey"

  def initialize(program, parent_exporter)
    if parent_exporter.class == ProgramExporter
      self.objs = parent_exporter.objs.first.surveys
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end
end