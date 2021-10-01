class CleanupRolesInClonedPrograms < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Common::RakeModule::Utils.execute_task do
        Program.where(creation_way: 1).includes(:translations, program_surveys: :recipient_roles, forums: :access_roles, mentoring_tips: :roles).select(:id).each do |program|
          program.program_surveys.each do |survey|
            survey.recipient_role_names = survey.recipient_roles.collect(&:name)
          end

          program.forums.select{|forum| forum.group_id.blank?}.each do |forum|
            forum.access_role_names = forum.access_roles.collect(&:name)
          end

          program.mentoring_tips.each do |mentoring_tip|
            mentoring_tip.role_names = mentoring_tip.roles.collect(&:name)
          end
        end
      end
    end
  end

  def down
    # do nothing
  end
end
