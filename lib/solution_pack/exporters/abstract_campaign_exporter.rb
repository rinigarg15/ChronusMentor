class AbstractCampaignExporter < SolutionPack::Exporter

  AssociatedExporters = ["AbstractCampaignMessageExporter"]
  FileName = "campaign"
  AssociatedModel = "CampaignManagement::AbstractCampaign"

  def initialize(program, parent_exporter)
    self.objs = program.abstract_campaigns
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end