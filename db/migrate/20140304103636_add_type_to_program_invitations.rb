class AddTypeToProgramInvitations< ActiveRecord::Migration[4.2]
  def up
    add_column :program_invitations, :role_type, :integer
    Program.find_each do |program|
      ActiveRecord::Base.transaction do
        say "Updating ProgramInvitation for id=#{program.id} name=#{program.name}", true
        program.program_invitations.includes(:roles).find_each do |invite|
          if invite.roles.present?
            invite.role_type = ProgramInvitation::RoleType::ASSIGN_ROLE
          else
            invite.role_type = ProgramInvitation::RoleType::ALLOW_ROLE
            invite.role_names = [RoleConstants::STUDENT_NAME, RoleConstants::MENTOR_NAME]
          end
          begin
            invite.save!
          rescue => e
            invite.save(validate: false)
            say "Issue: Invitation ID - #{invite.id} #{e.message}", true
          end
        end
      end
    end
  end

  def down
    Program.find_each do |program|
      ActiveRecord::Base.transaction do
        program.program_invitations.where(role_type: ProgramInvitation::RoleType::ALLOW_ROLE).find_each do |invite|
          invite.update_attribute(:role_names, [])
        end
      end
    end
    remove_column :program_invitations, :role_type
  end
end
