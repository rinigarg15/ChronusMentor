class OverviewPagesExporter < SolutionPack::Exporter
  FileName = 'overview_pages'
  AssociatedModel = "Page"

  def initialize(program, parent_exporter)
    if parent_exporter.class == ProgramExporter
      self.objs = program.standalone? ? program.organization.pages : program.pages
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

  def export_ck_editor_related_content
    self.objs.each do |obj|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, obj.content, self.solution_pack)
    end
  end
end