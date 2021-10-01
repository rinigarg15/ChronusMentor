class ForumExporter < SolutionPack::Exporter

  AssociatedExporters = ["RoleReferenceExporter"]
  SalesDemoExporters = ["RoleReferenceExporter", "TopicExporter"]
  FileName = "forum"
  AssociatedModel = "Forum"

  def initialize(program, parent_exporter)
    if parent_exporter.class == ProgramExporter
      self.objs = program.forums_enabled? ? parent_exporter.objs.first.forums.program_forums : []
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end
end