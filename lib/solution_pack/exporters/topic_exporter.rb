class TopicExporter < SolutionPack::Exporter

  AssociatedExporters = []
  SalesDemoExporters = ["PostExporter"]
  FileName = "topic"
  AssociatedModel = "Topic"

  def initialize(program, parent_exporter)
    if (parent_exporter.class == ForumExporter)
      self.objs = parent_exporter.objs.collect(&:topics).flatten
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  def export_ck_editor_related_content
    self.objs.each do |obj|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, obj.body, self.solution_pack)
    end
  end
end