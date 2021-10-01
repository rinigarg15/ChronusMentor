class MentoringModelLinkExporter < SolutionPack::Exporter

  FileName = 'mentoring_model_link'
  AssociatedModel = "MentoringModel::Link"

  def initialize(program, parent_exporter)
    if(parent_exporter.class == MentoringModelExporter)
      mentoring_models = parent_exporter.objs
      self.objs = program.mentoring_models.collect(&:child_links).flatten
    end

    self.program = program
    self.parent_exporter = parent_exporter
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end