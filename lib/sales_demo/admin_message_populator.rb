module SalesDemo
  class AdminMessagePopulator < BasePopulator
    REQUIRED_FIELDS = AdminMessage.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :admin_messages)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        am = AdminMessage.new.tap do |admin_message|
          assign_data(admin_message, ref_object)
          admin_message.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          admin_message.sender_id = master_populator.referer_hash[:member][ref_object.sender_id]
          admin_message.group_id = master_populator.referer_hash[:group][ref_object.group_id]
          admin_message.parent_id = referer[ref_object.parent_id]
          admin_message.content = self.master_populator.handle_ck_editor_import(ref_object.content)
          admin_message.campaign_message_id = master_populator.solution_pack_referer_hash["CampaignManagement::AbstractCampaignMessage"][ref_object.campaign_message_id]
        end
        AdminMessage.import([am], validate: false, timestamps: false)
        admin_message = AdminMessage.last
        unless ref_object.id == ref_object.root_id
          admin_message.update_column(:root_id, referer[ref_object.root_id])
        else
          admin_message.update_column(:root_id, admin_message.id)
        end
        referer[ref_object.id] = admin_message.id
      end
      master_populator.referer_hash[:admin_message] = referer
    end
  end
end

