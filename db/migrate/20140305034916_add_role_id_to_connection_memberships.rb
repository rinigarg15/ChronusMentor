class AddRoleIdToConnectionMemberships< ActiveRecord::Migration[4.2]
  def up
    add_column :connection_memberships, :role_id, :integer

    Program.includes(:roles).find_each do |program|
      say "Update roles for connection_memberships - #{program.name}", true
      ActiveRecord::Base.transaction do 
        role_hash = program.roles.group_by(&:name)
        program.connection_memberships.where(type: Connection::MentorMembership.name).update_all(
          role_id: role_hash[RoleConstants::MENTOR_NAME].first.id
        )
        program.connection_memberships.where(type: Connection::MenteeMembership.name).update_all(
          role_id: role_hash[RoleConstants::STUDENT_NAME].first.id
        )
      end
    end
  end

  def down
    remove_column :connection_memberships, :role_id
  end
end
