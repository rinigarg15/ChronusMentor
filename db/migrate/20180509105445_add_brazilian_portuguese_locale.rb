class AddBrazilianPortugueseLocale < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      DeploymentRakeRunner.add_rake_task("globalization:add_language TITLE='Brazilian Portuguese' DISPLAY_TITLE='Português brasileiro' LANGUAGE_NAME='pt-BR' ENABLED=true")
    end
  end

  def down
    #DO nothing
  end
end