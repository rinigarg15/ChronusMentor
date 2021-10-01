class AddCampaignAsFeature< ActiveRecord::Migration[4.2]
  def up
    if Feature.count > 0
      Feature.create_default_features
    end

    Organization.all.each do |org|
      org.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT)
    end

    Program.all.each do |prog|
      prog.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT)
    end
  end
end
