# USAGE: rake common:feature_manager:enable_feature_in_all_programs FEATURE="EXPLICIT_USER_PREFERENCES" SKIPPED_ORG_IDS="{development: [1,2,3], prodution: [], staging: []}"

namespace :common do
  namespace :feature_manager do
    desc "Enables feature in all the programs"
    task enable_feature_in_all_programs: :environment do
      if FeatureName.const_defined?(ENV["FEATURE"])
        feature = FeatureName.const_get(ENV["FEATURE"])
        puts "Enabling #{ENV["FEATURE"]}"
        org_ids_to_skip = eval(ENV["SKIPPED_ORG_IDS"])[Rails.env.to_sym] || []
        Program.includes([:disabled_db_features, {organization: :disabled_db_features}]).all.each do |program|
          if can_enable_feature?(feature, program, org_ids_to_skip)
            program.enable_feature(feature)
          else
            puts "Skipping for program with ID #{program.id}"
          end
        end
      else
        puts "Feature #{ENV["FEATURE"]} is invalid"
      end
    end

    private

    def can_enable_feature?(feature, program, org_ids_to_skip)
      !org_ids_to_skip.include?(program.parent_id) && !was_feature_disabled_explicitly?(feature, program)
    end

    def was_feature_disabled_explicitly?(feature, program)
      program.disabled_db_features.collect(&:name).include?(feature) || program.organization.disabled_db_features.collect(&:name).include?(feature)
    end
  end
end