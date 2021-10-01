class AbstractCampaignMessageExporter < SolutionPack::Exporter

  AssociatedExporters = ["MailerTemplateExporter"]
  FileName = 'campaign_message'
  AssociatedModel = "CampaignManagement::AbstractCampaignMessage"

  def initialize(program, parent_exporter)
    if parent_exporter.class == AbstractCampaignExporter
      self.objs = CampaignManagement::AbstractCampaignMessage.where("campaign_id IN (?)", parent_exporter.objs.collect(&:id))
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.file_name = FileName
    self.solution_pack = parent_exporter.solution_pack
  end

end