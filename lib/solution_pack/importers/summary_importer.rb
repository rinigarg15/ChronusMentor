class SummaryImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["connection_question_id"]
  AssociatedModel = "Summary"
  FileName = 'summary'

  def initialize(parent_importer)
    super parent_importer
    self.file_name = FileName + '_' + parent_importer.class::FileName
  end

  def process_connection_question_id(connection_question_id, obj)
    obj.connection_question_id = self.solution_pack.id_mappings[self.parent_importer.class::AssociatedModel][connection_question_id.to_i]
  end
end