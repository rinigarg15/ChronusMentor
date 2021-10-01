class AbstractCampaignMessageImporter < SolutionPack::Importer

  NoImportAttributes = ["created_at", "updated_at", "user_jobs_created"]
  CustomAttributes = ["campaign_id", "sender_id"]

  AssociatedModel = "CampaignManagement::AbstractCampaignMessage"
  FileName = 'campaign_message'

  def initialize(parent_importer)
    super parent_importer
  end

  def process_campaign_id(campaign_id, obj)
    obj.campaign_id = self.solution_pack.id_mappings[AbstractCampaignImporter::AssociatedModel][campaign_id.to_i]
  end

  def process_sender_id(sender_id, obj)
    obj.sender_id = nil
  end

  def process_email_template(obj, old_id)
    obj.email_template = Mailer::Template.find(self.parent_importer.campaign_message_mailer_template_id_mapping[old_id.to_i])
    obj.email_template.belongs_to_cm = true
  end

  def handle_object_creation(obj, old_id, column_names, row)
    campaign_message = nil
    unless self.parent_importer.campaign_message_ids_for_skip.include?(old_id.to_i)
      process_email_template(obj, old_id)
      attributes  = obj.attributes
      campaign_id = attributes.delete("campaign_id")
      campaign_message_type = attributes.delete('type')
      NoImportAttributes.each {|x| attributes.delete(x)} #Getting mass-assignment error for created_at and updated_at
      attributes.delete('id')

      # Create the corresponding subclass and save. Otherwise observers of the subclass do not get called
      campaign_message = campaign_message_type.constantize.new(attributes)
      campaign_message.email_template = obj.email_template
      campaign_message.campaign_id = campaign_id
      campaign_message.save!
    end
    campaign_message || obj 
  end

end