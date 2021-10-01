class AdminViewExporter < SolutionPack::Exporter

  AssociatedExporters = ["AdminViewColumnExporter"]
  FileName = 'admin_view'
  AssociatedModel = "AdminView"

  def initialize(program, parent_exporter)
    self.objs = program.admin_views
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end