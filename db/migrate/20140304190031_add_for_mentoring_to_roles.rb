class AddForMentoringToRoles< ActiveRecord::Migration[4.2]
  def up
    add_column :roles, :for_mentoring, :boolean, default: false
    Role.reset_column_information

    Role.transaction do
      Role.where(name: [RoleConstants::MENTOR_NAME, RoleConstants::STUDENT_NAME]).find_each do |role|
        role.for_mentoring = true
        role.save!
      end
    end
  end

  def down
    remove_column :roles, :for_mentoring
  end
end
