class UpdateBasfGroupNames< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      if Rails.env.productioneu?
        organization = Program::Domain.get_organization("chronus.com", "mentforme")
        program_ids = organization.programs.pluck(:id)
        groups = Group.where(program_id: program_ids).where("name like '% and %'")
        groups.each do |group|
          group_name = group.name
          group.update_columns(name: group_name.gsub(' and ', ' & '), skip_delta_indexing: true)
        end
        DeploymentRakeRunner.add_rake_task("es_indexes:full_indexing MODELS='#{Group.name}'")
      end
    end
  end

  def down
    # DO nothing
  end
end