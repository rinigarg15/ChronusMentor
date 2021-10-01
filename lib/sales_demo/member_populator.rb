module SalesDemo
  class MemberPopulator < BasePopulator
    REQUIRED_FIELDS = Member.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :members)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        m = Member.new.tap do |member|
          assign_data(member, ref_object)
          member.organization_id = master_populator.referer_hash[:organization][ref_object.organization_id]
          member.crypted_password = "3f8ffdd4fa5c84220d35ea51d31448417fbb9cc6bafc9a4554b56241b1160cd12827d09210d8ffd3ef29de90145ea4443881c8fee00751ae4af35815a8cb9707" #Chronus123
          member.salt = "da4b9237bacccdf19c0760cab7aec4a8359010b0"
          member.encryption_type = Member::EncryptionType::SHA2
        end

        # For mentoradmin, we should update the password with the latest demo mentoradmin lastpass password,
        # we will find the maximum repeating mentoradmin password, this will mostly be the demo mentoradmin
        # lastpass password, below we are finding it and updating it
        if m.email == SUPERADMIN_EMAIL
          passwords_data = Member.where(email: SUPERADMIN_EMAIL).map { |member| "#{member.crypted_password}:#{member.salt}" }
          if passwords_data.any?
            crypted_password, salt = passwords_data.uniq.map { |p| [p, passwords_data.count(p)] }.sort_by { |x| x[1] }.last[0].split(":")
            m.crypted_password = crypted_password
            m.salt = salt
          end
        end
        Member.import([m], validate: false, timestamps: false)

        new_member = Member.last
        login_identifier = LoginIdentifier.new(member_id: new_member.id, auth_config_id: new_member.organization.chronus_auth.id)
        LoginIdentifier.import([login_identifier], validate: false)
        referer[ref_object.id] = new_member.id
      end
      master_populator.referer_hash[:member] = referer
    end
  end
end