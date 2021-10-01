class ConnectionQuestionExporter < SolutionPack::Exporter

  AssociatedExporters = ["QuestionChoiceExporter", "SummaryExporter"]
  FileName = 'connection_question'
  AssociatedModel = "Connection::Question"

  def initialize(program, parent_exporter)
    self.objs = program.connection_questions
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end