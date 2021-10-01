class ResourceExporter < SolutionPack::Exporter

  AssociatedExporters = ["ResourcePublicationExporter"]
  FileName = "resource"
  AssociatedModel = "Resource"

  def initialize(program, parent_exporter)
    self.objs = program.resource_publications.collect(&:resource)
    self.objs.select(&:is_organization?).reject(&:default?) if parent_exporter.solution_pack.is_sales_demo
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  def export_ck_editor_related_content
    self.objs.each do |resource|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, resource.content, self.solution_pack)
    end
  end

end