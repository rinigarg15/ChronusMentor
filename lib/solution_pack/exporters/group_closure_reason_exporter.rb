class GroupClosureReasonExporter < SolutionPack::Exporter

  AssociatedExporters = []
  FileName = "group_closure_reason"
  AssociatedModel = "GroupClosureReason"

  def initialize(program, parent_exporter)
    self.objs = program.group_closure_reasons
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end