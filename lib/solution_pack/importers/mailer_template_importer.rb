class MailerTemplateImporter < SolutionPack::Importer

  attr_accessor :campaign_message_mailer_template_id_mapping, :campaign_message_ids_for_skip

  NoImportAttributes = ["created_at", "updated_at", "copied_content"]
  CustomAttributes = ["campaign_message_id"]

  AssociatedImporters = ["AbstractCampaignMessageImporter"]

  AssociatedModel = "Mailer::Template"
  FileName = 'mailer_template'

  def initialize(parent_importer)
    self.file_name = FileName
    if parent_importer.class == AbstractCampaignImporter
      self.file_name = FileName + '_' + AbstractCampaignMessageImporter::FileName
    elsif parent_importer.class == ProgramImporter
      self.file_name = FileName
    end
    self.parent_importer = parent_importer
    self.solution_pack = parent_importer.solution_pack
    self.solution_pack.id_mappings[AssociatedModel] = {}
    self.campaign_message_mailer_template_id_mapping = {}
    self.campaign_message_ids_for_skip = []
  end

  def handle_object_creation(obj, old_id, column_names, row)
    begin
      program_id = get_program_id(obj)
      #program_id is nil in case of org level mailer templates. Ignore these templates.
      return obj if program_id.nil?
      obj.program_id = program_id
      mailer_template_belongs_to_cm = obj.campaign_message_id.present?
      if mailer_template_belongs_to_cm
        obj.belongs_to_cm = true
        old_campaign_message_id = obj.campaign_message_id
        obj.campaign_message_id = nil
      end
      mailer_template_belongs_to_cm ? obj.program.mailer_templates.non_campaign_mails.find_by(uid: obj.uid).try(:destroy) : obj.program.mailer_templates.find_by(uid: obj.uid).try(:destroy) if obj.uid
      import_ck_editor_columns(obj)
      obj.save!
      self.campaign_message_mailer_template_id_mapping[old_campaign_message_id] = obj.id if mailer_template_belongs_to_cm
    rescue
      handle_error_case(obj, column_names, row)
      return nil
    end
    obj
  end

  def import_ck_editor_columns(mailer_template)
    updated_source = SolutionPack::CkeditorExportImportUtils.handle_ck_editor_import(solution_pack.program, solution_pack, mailer_template.source, solution_pack.ck_editor_column_names, solution_pack.ck_editor_rows)
    mailer_template.source = updated_source
    mailer_template.save!
  end

  def process_campaign_message_id(campaign_message_id, obj)
    if self.parent_importer.class == AbstractCampaignImporter
      obj.campaign_message_id = campaign_message_id.to_i #replaced with correct value in campaign message importer
    end
  end

  private

  def handle_error_case(obj, column_names, row)
    uid_index = column_names.index("uid")
    err = ActiveModel::Errors.new(self.solution_pack)
    err.add(:base, "Error in importing with UID #{row[uid_index]}. Full Error Message #{obj.errors.full_messages.join(", ")}")
    self.solution_pack.custom_errors << SolutionPack::Error.new(SolutionPack::Error::TYPE::MailerTemplate, err)
    self.campaign_message_ids_for_skip << obj.campaign_message_id if obj.campaign_message_id.present?
  end

  def get_program_id(obj)
    return self.solution_pack.program.id if obj.uid.nil?
    level = ChronusActionMailer::Base.get_descendants.find{|klass| klass.mailer_attributes[:uid] == obj.uid}.mailer_attributes[:level]
    #org level mailer templates should not be imported, so return nil here.
    (level == EmailCustomization::Level::ORGANIZATION) ? nil : self.solution_pack.program.id
  end

end
