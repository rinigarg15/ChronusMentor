class EnableCampaignManagementFeature < ActiveRecord::Migration[4.2]

  def change
    Program.all.each do |program|
      if !program.has_feature?(FeatureName::CAMPAIGN_MANAGEMENT)
      	program.organization.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT)
        program.enable_feature(FeatureName::CAMPAIGN_MANAGEMENT)
        program.populate_default_campaigns
      end  
    end
  end
end
