class SummaryExporter < SolutionPack::Exporter

  FileName = 'summary'
  AssociatedModel = "Summary"

  def initialize(program, parent_exporter)
    self.objs = program.summaries
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName + '_' + parent_exporter.class::FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end