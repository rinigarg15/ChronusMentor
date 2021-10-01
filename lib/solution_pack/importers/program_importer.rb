class ProgramImporter < SolutionPack::Importer

  AssociatedImporters = ["RoleImporter", "CustomizedTermImporter", "GroupClosureReasonImporter", "SettingsImporter","ForumImporter", "SurveyImporter", "MentoringModelImporter", "SectionImporter", "AdminViewImporter", "AbstractCampaignImporter", "ResourceImporter", "MailerTemplateImporter",  "OverviewPagesImporter", "ConnectionQuestionImporter"]
  #TODO #CareerDev - Refactor and remove this constant
  CareerDevAssociatedImporters = ["RoleImporter", "CustomizedTermImporter", "SettingsImporter","ForumImporter", "SurveyImporter", "SectionImporter", "AdminViewImporter", "AbstractCampaignImporter", "ResourceImporter", "MailerTemplateImporter"]
  FileName = 'program'

  def initialize(solution_pack, options = {})
    self.solution_pack = solution_pack
    self.solution_pack.id_mappings = {}
    self.custom_associated_importers = options[:custom_associated_importers]
    self.skipped_associated_importers = options[:skipped_associated_importers]
  end

  def import
    import_associated_content(self, self.associated_importers)
  end
end