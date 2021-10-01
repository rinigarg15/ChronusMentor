module SalesDemo
  class ScrapPopulator < BasePopulator
    REQUIRED_FIELDS = Scrap.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :scraps)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        sp = Scrap.new.tap do |scrap|
          assign_data(scrap, ref_object)
          scrap.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          scrap.sender_id = master_populator.referer_hash[:member][ref_object.sender_id]
          scrap.ref_obj_id = master_populator.referer_hash[:group][ref_object.ref_obj_id]
          scrap.ref_obj_type = Group.to_s
          scrap.parent_id = referer[ref_object.parent_id]
          scrap.campaign_message_id = master_populator.solution_pack_referer_hash["CampaignManagement::AbstractCampaignMessage"][ref_object.campaign_message_id]
          SolutionPack::AttachmentExportImportUtils.handle_attachment_import(SalesPopulator::ATTACHMENT_FOLDER + "scraps/", scrap, :attachment, scrap.attachment_file_name, ref_object.id)
        end
        scrap = Scrap.last
        unless ref_object.id == ref_object.root_id
          scrap.update_column(:root_id, referer[ref_object.root_id])
        else
          scrap.update_column(:root_id, scrap.id)
        end
        referer[ref_object.id] = scrap.id
      end
      master_populator.referer_hash[:scrap] = referer
    end
  end
end