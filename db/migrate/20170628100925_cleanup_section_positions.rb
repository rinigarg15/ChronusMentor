class CleanupSectionPositions< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      default_sections = Section.default_section
      if default_sections.group(:program_id).size.select {|org_id, default_sections| default_sections > 1}.blank?
        default_sections.where.not(position: 1).update_all(position: 1)
      else
      	raise "Atleast one organization has more than one default section"
      end
    end
  end
end
