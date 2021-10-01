class SurveyQuestionExporter < SolutionPack::Exporter

  AssociatedExporters = ["QuestionChoiceExporter"]
  FileName = 'survey_question'
  AssociatedModel = "SurveyQuestion"

  def initialize(program, parent_exporter)
    if (parent_exporter.class == SurveyExporter)
      self.objs = parent_exporter.objs.collect(&:survey_questions).flatten
      self.objs += parent_exporter.objs.collect(&:matrix_rating_questions).flatten
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName + '_' + parent_exporter.class::FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end