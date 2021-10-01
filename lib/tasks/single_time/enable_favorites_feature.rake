namespace :single_time do
  desc 'Enabling favorite/ignore profile feature for SMP programs'
  task :enable_favorites_feature => :environment do
    skipped_org_ids = {
      # development: [],
      staging: [816, 1465],
      production: [1336, 1714]
    }

    Organization.active.each do |org|
      unless (skipped_org_ids[Rails.env.to_sym]||[]).include?(org.id)
        org.enable_feature(FeatureName::SKIP_AND_FAVORITE_PROFILES)
      end
    end

    Program.active.each do |program|
      program.enable_feature(FeatureName::SKIP_AND_FAVORITE_PROFILES, false) unless program.matching_by_mentee_alone?
    end
  end
end