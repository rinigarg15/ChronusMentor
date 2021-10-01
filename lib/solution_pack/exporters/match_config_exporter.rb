class MatchConfigExporter < SolutionPack::Exporter

  FileName = "match_config"
  AssociatedModel = "MatchConfig"

  def initialize(program, parent_exporter)
    self.objs = program.match_configs
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end