class EnableMentoringModelTasksAndMessagesTemplates< ActiveRecord::Migration[4.2]
  def change
    Program.find_each do |program|
      roles_hash = program.roles.with_name(RoleConstants::DEFAULT_ROLE_NAMES).group_by(&:name)
      all_roles = roles_hash.values.flatten
      admin_roles = roles_hash[RoleConstants::ADMIN_NAME]       
      program.mentoring_models.each do |mentoring_model|
        ActiveRecord::Base.transaction do
          mentoring_model.send("allow_#{ObjectPermission::MentoringModel::TASK}!", all_roles)
          mentoring_model.send("allow_#{ObjectPermission::MentoringModel::FACILITATION_MESSAGE}!", admin_roles)
        end
      end
    end
  end
end