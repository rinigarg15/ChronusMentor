class SectionExporter < SolutionPack::Exporter

  AssociatedExporters = ["ProfileQuestionExporter"]
  FileName = 'section'
  AssociatedModel = "Section"

  def initialize(program, parent_exporter)
    self.objs = parent_exporter.solution_pack.is_sales_demo ? program.organization.sections : program.role_questions.includes([:profile_question => [:section]]).collect(&:profile_question).collect(&:section).uniq.flatten
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end