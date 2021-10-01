class EnableWorkOnBehalfFeatureInAllOrgs < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      unless Rails.env.test?
        feature = Feature.create!(name: FeatureName::WORK_ON_BEHALF)
        Organization.pluck(:id).each do |organization_id|
          OrganizationFeature.create!(organization_id: organization_id, feature_id: feature.id)
        end
      end
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      unless Rails.env.test?
        Feature.find_by(name: FeatureName::WORK_ON_BEHALF).destroy
      end
    end
  end
end
