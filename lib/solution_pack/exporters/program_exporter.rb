class ProgramExporter < SolutionPack::Exporter

  AssociatedExporters = ["RoleExporter", "CustomizedTermExporter", "SettingsExporter", "SurveyExporter", "ForumExporter", "SectionExporter", "AdminViewExporter", "AbstractCampaignExporter", "MentoringModelExporter", "ResourceExporter", "CkeditorAssetExporter", "MailerTemplateExporter", "GroupClosureReasonExporter", "OverviewPagesExporter", "ConnectionQuestionExporter"]
  CareerDevAssociatedExporters = ["RoleExporter", "CustomizedTermExporter", "SettingsExporter", "SurveyExporter", "ForumExporter", "SectionExporter", "AdminViewExporter", "AbstractCampaignExporter", "ResourceExporter", "CkeditorAssetExporter", "MailerTemplateExporter"]
  FileName = 'program'

  def initialize(program, solution_pack, options = {})
    self.objs = [program]
    self.program = program
    self.solution_pack = solution_pack
    self.custom_associated_exporters = options[:custom_associated_exporters]
    self.skipped_associated_exporters = options[:skipped_associated_exporters]
  end

  def export
    self.export_associated_content(self.program)
  end

end