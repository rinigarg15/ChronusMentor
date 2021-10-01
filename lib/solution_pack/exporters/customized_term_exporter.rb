class CustomizedTermExporter < SolutionPack::Exporter

  FileName = 'customized_term_'
  AssociatedModel = "CustomizedTerm"

  def initialize(program, parent_exporter)
    if parent_exporter.class == RoleExporter
      self.objs = parent_exporter.objs.collect(&:customized_term)
    elsif parent_exporter.class == ProgramExporter
      self.objs = program.customized_terms
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.solution_pack = parent_exporter.solution_pack
    self.file_name = FileName + parent_exporter.class::FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end