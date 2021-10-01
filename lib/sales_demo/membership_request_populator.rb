module SalesDemo
  class MembershipRequestPopulator < BasePopulator
    REQUIRED_FIELDS = MembershipRequest.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :membership_requests)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        m = MembershipRequest.new.tap do |membership_request|
          assign_data(membership_request, ref_object)
          membership_request.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          membership_request.admin_id = master_populator.referer_hash[:user][ref_object.admin_id]
          membership_request.member_id = master_populator.referer_hash[:member][ref_object.member_id] if ref_object.member_id.present?
        end
        MembershipRequest.import([m], validate: false, timestamps: false)
        membership_request = MembershipRequest.last
        membership_request.role_names = Marshal.load(ref_object.role_names)
        referer[ref_object.id] = MembershipRequest.last.id
      end
      master_populator.referer_hash[:membership_request] = referer
    end


    DUMPING_FIELDS = MembershipRequest.attribute_names.map(&:to_sym) + [:role_names]
    def self.dump_data(membership_requests)
      return membership_requests.collect do |membership_request|
        DUMPING_FIELDS.inject({}) do |hash_map, field|
          value = membership_request.send(field)
          hash_map[field] = value.is_a?(Array) ?  Marshal.dump(value) : value
          hash_map
        end
      end
    end
  end
end