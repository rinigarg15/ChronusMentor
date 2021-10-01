class RoleQuestionExporter < SolutionPack::Exporter

  FileName = 'role_question'
  AssociatedModel = "RoleQuestion"
  AssociatedExporters = ["RoleQuestionPrivacySettingExporter", "MatchConfigExporter"]
  CareerDevAssociatedExporters = ["RoleQuestionPrivacySettingExporter"]

  def initialize(program, parent_exporter)
    self.objs = program.role_questions
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end