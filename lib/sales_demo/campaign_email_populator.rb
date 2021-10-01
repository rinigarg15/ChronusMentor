module SalesDemo
  class CampaignEmailPopulator < BasePopulator
    REQUIRED_FIELDS = CampaignManagement::CampaignEmail.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :campaign_management_campaign_emails)
    end

    def copy_data
      campaign_message_id_hash = {}
      self.reference.each do |ref_object|
        ce = CampaignManagement::CampaignEmail.new.tap do |campaign_email|
          assign_data(campaign_email, ref_object)
          campaign_email.campaign_message_id = master_populator.solution_pack_referer_hash["CampaignManagement::AbstractCampaignMessage"][ref_object.campaign_message_id]
          campaign_email.source = self.master_populator.handle_ck_editor_import(ref_object.source)
          campaign_message = campaign_message_id_hash[campaign_email.campaign_message_id]
          if campaign_message.blank?
            campaign_message = campaign_email.campaign_message
            campaign_message_id_hash[campaign_email.campaign_message_id] = campaign_message
          end
          campaign_email.abstract_object_id = (campaign_message.type == CampaignManagement::AbstractCampaignMessage::TYPE::SURVEY) ? ((campaign_message.campaign.abstract_object_klass == MentoringModel::Task) ? master_populator.referer_hash[:mentoring_model_task][ref_object.abstract_object_id] : master_populator.referer_hash[:member_meeting][ref_object.abstract_object_id]) : master_populator.referer_hash[:program_invitation][ref_object.abstract_object_id]
        end
        CampaignManagement::CampaignEmail.import([ce], validate: false, timestamps: false)
      end
    end
  end
end

