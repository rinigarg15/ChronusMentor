class AbstractCampaignImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at"]
  CustomAttributes = ["program_id", "trigger_params", "enabled_at", "ref_obj_id"]

  AssociatedImporters = ["MailerTemplateImporter"]

  AssociatedModel = "CampaignManagement::AbstractCampaign"
  FileName = 'campaign'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_program_id(program_id, obj)
    obj.program_id = self.solution_pack.program.id
  end

  def process_trigger_params(trigger_params, obj)
    if !trigger_params.nil?
      trigger_params = eval(trigger_params)
      trigger_params[1].each_with_index do |admin_view_id, index|
        trigger_params[1][index] = self.solution_pack.id_mappings[AdminViewImporter::AssociatedModel][admin_view_id]
      end
    end
    obj.trigger_params = trigger_params
  end

  def process_enabled_at(enabled_at, obj)
    if enabled_at.present?
      obj.enabled_at = Time.now
    end
  end

  def process_ref_obj_id(ref_obj_id, obj)
    obj.ref_obj_id = self.solution_pack.id_mappings[SurveyImporter::AssociatedModel][ref_obj_id.to_i] if ref_obj_id.present?
  end

end