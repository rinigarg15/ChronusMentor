class ConnectionQuestionImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "common_answers_count", "position"]
  CustomAttributes = ["program_id"]
  AssociatedImporters = ["QuestionChoiceImporter", "SummaryImporter"]
  AssociatedModel = "Connection::Question"
  FileName = 'connection_question'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(_program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end
end