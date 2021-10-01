class CreateNewDefaultAdminViewsForMatchReport < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Program.includes([:translations, :enabled_db_features, :disabled_db_features, organization: [:enabled_db_features, :disabled_db_features]]).select(&:can_have_match_report?).each do |program|
        ActiveRecord::Base.transaction do
          begin
            puts "Starting for program with id #{program.id}"
            program.create_default_match_report_admin_views
          rescue => error
            puts "Error:: #{error.message} for program with id #{program.id}"
          end
        end
      end
    end
  end

  def down
    #Do Nothing
  end
end
