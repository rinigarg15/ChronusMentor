class ProfileQuestionExporter < SolutionPack::Exporter

  FileName = 'profile_question'
  AssociatedModel = "ProfileQuestion"
  AssociatedExporters = ["RoleQuestionExporter", "QuestionChoiceExporter", "ConditionalMatchChoiceExporter"]

  def initialize(program, parent_exporter)
    self.objs = parent_exporter.solution_pack.is_sales_demo ? program.organization.profile_questions_with_email_and_name : program.role_questions.includes(:profile_question).collect(&:profile_question).uniq
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end