class UpdateStandaloneOrgNames < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Organization.where(programs_count: 1).includes(:programs).each do |organization|
        program = organization.programs.first
        organization.update_attributes!(name: program.name, description: program.description)
      end
    end
  end

  def down
    #Do nothing
  end
end