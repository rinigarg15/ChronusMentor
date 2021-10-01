class CreateProgramLanguages < ActiveRecord::Migration[4.2]

  def up
    ChronusMigrate.ddl_migration do
      create_table :program_languages do |t|
        t.references :organization_language
        t.references :program
        t.timestamps null: false
      end
    end

    ChronusMigrate.data_migration(has_downtime: false) do
      organization_id_organization_language_map = OrganizationLanguage.all.group_by(&:organization_id)

      organization_ids = organization_id_organization_language_map.keys
      Program.where(parent_id: organization_ids).each do |program|
        organization_languages = organization_id_organization_language_map[program.parent_id]
        organization_languages.each do |organization_language|
          organization_language.program_languages.create!(program: program)
        end
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      drop_table :program_languages
    end
  end
end
