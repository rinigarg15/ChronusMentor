module SalesDemo
  class AdminMessageReceiverPopulator < BasePopulator
    REQUIRED_FIELDS = AdminMessages::Receiver.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :admin_messages_receivers)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        amr = AdminMessages::Receiver.new.tap do |admin_message_receiver|
          assign_data(admin_message_receiver, ref_object)
          admin_message_receiver.member_id = master_populator.referer_hash[:member][ref_object.member_id] if master_populator.referer_hash[:member][ref_object.member_id]
          admin_message_receiver.message_id = master_populator.referer_hash[:admin_message][ref_object.message_id]
          admin_message_receiver.message_root_id = master_populator.referer_hash[:admin_message][ref_object.message_root_id]
        end
        AdminMessages::Receiver.import([amr], validate: false, timestamps: false)
        referer[ref_object.id] = AdminMessages::Receiver.last.id
      end
    end
  end
end

