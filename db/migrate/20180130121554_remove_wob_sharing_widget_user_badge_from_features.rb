class RemoveWobSharingWidgetUserBadgeFromFeatures < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.data_migration(has_downtime: false) do
      Feature.where(name: ["work_on_behalf", "sharing_widget", "user_badge"]).destroy_all
    end
  end

  def down
    ChronusMigrate.data_migration(has_downtime: false) do
      ["work_on_behalf", "sharing_widget", "user_badge"].each do |feature_name|
        feature = Feature.create!(name: feature_name)
        next unless feature_name.in?(["work_on_behalf", "sharing_widget"])

        Organization.all.each do |organization|
          OrganizationFeature.create!(organization_id: organization.id, feature_id: feature.id)
        end
      end
    end
  end
end