class OverviewPagesImporter < SolutionPack::Importer
  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["program_id", "content"]
  AssociatedModel = "Page"
  FileName = 'overview_pages'

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.standalone? ? self.solution_pack.program.organization.id : self.solution_pack.program.id
  end

  def process_content(content, obj)
    obj.content = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(self.solution_pack.program, self.solution_pack, content, self.solution_pack.ck_editor_column_names, self.solution_pack.ck_editor_rows)
  end

  def handle_object_creation(obj, old_id, column_names, row)
    obj.save!
    obj
  end
end