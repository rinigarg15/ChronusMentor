class AddManagementTypeToRoles< ActiveRecord::Migration[4.2]
  def up
    add_column :roles, :administrative, :boolean, default: false
    ActiveRecord::Base.transaction do
      Role.all.each do |role|
        role.update_attribute(:administrative, [RoleConstants::ADMIN_NAME, RoleConstants::COMMITTEE_MEMBER_NAME, RoleConstants::BOARD_OF_ADVISOR_NAME].include?(role.name))
      end
    end
  end

  def down
    remove_column :roles, :administrative
  end
end
