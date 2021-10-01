module SalesDemo
  class UserPopulator < BasePopulator
    REQUIRED_FIELDS = User.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at, :activated_at, :last_seen_at, :profile_updated_at]

    def initialize(master_populator)
      super(master_populator, :users)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        u = User.new.tap do |user|
          assign_data(user, ref_object)
          user.program_id = master_populator.referer_hash[:program][ref_object.program_id]
          user.member_id = master_populator.referer_hash[:member][ref_object.member_id]
          user.created_for_sales_demo = true
        end
        User.import([u], validate: false, timestamps: false)
        user = User.last
        referer[ref_object.id] = user.id
        user.created_for_sales_demo = true
        user.role_names = Marshal.load(ref_object.role_names)
      end
      master_populator.referer_hash[:user] = referer
    end


    DUMPING_FIELDS = User.attribute_names.map(&:to_sym) + [:role_names]
    def self.dump_data(users)
      return users.collect do |user|
        DUMPING_FIELDS.inject({}) do |hash_map, field|
          value = user.send(field)
          hash_map[field] = value.is_a?(Array) ?  Marshal.dump(value) : value
          hash_map
        end
      end
    end
  end
end