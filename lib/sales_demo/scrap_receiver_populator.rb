module SalesDemo
  class ScrapReceiverPopulator < BasePopulator
    REQUIRED_FIELDS = Scraps::Receiver.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :scraps_receivers)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        sr = Scraps::Receiver.new.tap do |scrap_receiver|
          assign_data(scrap_receiver, ref_object)
          scrap_receiver.member_id = master_populator.referer_hash[:member][ref_object.member_id] if master_populator.referer_hash[:member][ref_object.member_id]
          scrap_receiver.message_id = master_populator.referer_hash[:scrap][ref_object.message_id]
          scrap_receiver.message_root_id = master_populator.referer_hash[:scrap][ref_object.message_root_id]
        end
        Scraps::Receiver.import([sr], validate: false, timestamps: false)
        referer[ref_object.id] = Scraps::Receiver.last.id
      end
    end
  end
end

