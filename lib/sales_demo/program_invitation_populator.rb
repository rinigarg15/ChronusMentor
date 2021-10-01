module SalesDemo
  class ProgramInvitationPopulator < BasePopulator
    REQUIRED_FIELDS = ProgramInvitation.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:expires_on, :sent_on, :redeemed_at, :created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :program_invitations)
    end

    def copy_data
      referer = {}
      self.reference.each do |ref_object|
        pi = ProgramInvitation.new.tap do |program_invitation|
          assign_data(program_invitation, ref_object)
          program_invitation.user_id = master_populator.referer_hash[:user][ref_object.user_id]
          program_invitation.message = self.master_populator.handle_ck_editor_import(ref_object.message)
          program_invitation.program_id = master_populator.referer_hash[:program][ref_object.program_id]
        end
        ProgramInvitation.import([pi], validate: false, timestamps: false)
        referer[ref_object.id] = ProgramInvitation.last.id
      end
      master_populator.referer_hash[:program_invitation] = referer
    end
  end
end

