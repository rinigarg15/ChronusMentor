class MigratePagesOfStandaloneProgramToOrganization< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      standalone_organization_ids = Organization.where(programs_count: 1).pluck(:id)
      standalone_programs = Program.where(parent_id: standalone_organization_ids).includes(:translations, :pages)
      migrated_program_urls = []
      standalone_programs.each do |standalone_program|
        next if standalone_program.pages.blank?
        standalone_program.handle_pages_of_standalone_program
        migrated_program_urls << standalone_program.url
      end
      puts "Standalone Programs Migrated: #{migrated_program_urls.join(",")}"
    end
  end

  def down
    #do nothing
  end
end