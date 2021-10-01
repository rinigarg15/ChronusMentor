class PostExporter < SolutionPack::Exporter

  AssociatedExporters = []
  FileName = "post"
  AssociatedModel = "Post"

  def initialize(program, parent_exporter)
    if (parent_exporter.class == TopicExporter)
      self.objs = parent_exporter.objs.collect(&:posts).flatten
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  def export_ck_editor_related_content
    self.objs.each do |obj|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, obj.body, self.solution_pack)
      SolutionPack::AttachmentExportImportUtils.handle_attachment_export(self.solution_pack.post_attachment_base_path, obj, "attachment")
    end
  end
end