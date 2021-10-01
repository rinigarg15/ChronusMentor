class ProgramInvitationPopulator < PopulatorTask

  def patch(options = {})
    program_ids = @organization.programs.pluck(:id)
    program_invitations_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, program_ids)
    process_patch(program_ids, program_invitations_hsh) 
  end

  def add_program_invitations(program_ids, count, options = {})
    self.class.benchmark_wrapper "Program Invitations" do
      programs = Program.where(id: program_ids)
      programs.each do |program|
        invitation_iterator = ProgramInvitation.count
        lower_bound = program.created_at
        upper_bound = Time.now
        admin_user = program.admin_users.sample
        role_ids = program.roles.non_administrative.pluck(:id)
        ProgramInvitation.populate(count) do |program_invitation|
          program_invitation.user_id = admin_user.id
          program_invitation.code = "invitation#{invitation_iterator}#{self.class.random_string}"
          program_invitation.sent_to = "invitation_#{invitation_iterator}_#{self.class.random_string}+minimal@chronus.com"
          program_invitation.sent_on = lower_bound..upper_bound
          program_invitation.expires_on = program_invitation.sent_on + 30.days
          program_invitation.program_id = program.id
          program_invitation.use_count = 0
          program_invitation.message = Populator.paragraphs(2..4)
          program_invitation.role_type = [ProgramInvitation::RoleType::ASSIGN_ROLE, ProgramInvitation::RoleType::ALLOW_ROLE]
          create_role_reference(ProgramInvitation, program_invitation.id, role_ids, (1..role_ids.size).to_a.sample)
          invitation_iterator += 1
          self.dot
        end
      end
      self.class.display_populated_count(program_ids.size * count, "Program Invitations")
    end
  end

  def remove_program_invitations(program_ids, count, options = {})
    self.class.benchmark_wrapper "Removing Program Invitation................" do
      program_invitation_ids = ProgramInvitation.where(:program_id => program_ids).select([:id, :program_id]).group_by(&:program_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      ProgramInvitation.where(:id => program_invitation_ids).destroy_all
      self.class.display_deleted_count(program_ids.size * count, "Program Invitations")
    end
  end
end