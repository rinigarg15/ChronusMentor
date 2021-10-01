class CkeditorAssetExporter < SolutionPack::Exporter

  AssociatedExporter = []
  FileName = 'ckeditor_asset'
  AssociatedModel = "Ckeditor::Asset"
  AdditionalAttributes = { "url": :path_for_ckeditor_asset }

  def initialize(program, parent_exporter)
    self.objs = Ckeditor::Asset.where(program_id: program.organization.id)
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end
end