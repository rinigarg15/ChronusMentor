class MailerTemplateExporter < SolutionPack::Exporter

  FileName = 'mailer_template'
  AssociatedModel = "Mailer::Template"

  def initialize(program, parent_exporter)
    if parent_exporter.class == AbstractCampaignMessageExporter
      self.objs = Mailer::Template.where("campaign_message_id IN (?)", parent_exporter.objs.collect(&:id).uniq)
      self.file_name = FileName + '_' + AbstractCampaignMessageExporter::FileName
    elsif parent_exporter.class == ProgramExporter
      self.objs = program.mailer_templates.where("campaign_message_id is NULL")
      mail_uids = self.objs.collect(&:uid)
      if mail_uids.present?
        self.objs += program.organization.mailer_templates.where("campaign_message_id is NULL and uid not in (?)", mail_uids)
      else
        self.objs += program.organization.mailer_templates.where("campaign_message_id is NULL")
      end
      self.file_name = FileName
    end
    self.parent_exporter = parent_exporter
    self.program = program
    self.solution_pack = parent_exporter.solution_pack
  end

  def export_ck_editor_related_content
    self.objs.each do |mailer_template|
      SolutionPack::CkeditorExportImportUtils.handle_ck_editor_export(self.program, mailer_template.source, self.solution_pack)
    end
  end

end