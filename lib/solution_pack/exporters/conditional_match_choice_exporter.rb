class ConditionalMatchChoiceExporter < SolutionPack::Exporter
  FileName = 'conditional_match_choice'
  AssociatedModel = "ConditionalMatchChoice"
  AssociatedExporters = []

  def initialize(program, parent_exporter)
    self.objs = ConditionalMatchChoice.where(profile_question_id: parent_exporter.objs.collect(&:id))
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end
end