module SalesDemo
  class CampaignMessageAnalyticsPopulator < BasePopulator
    REQUIRED_FIELDS = CampaignManagement::CampaignMessageAnalytics.attribute_names.map(&:to_sym) - [:id]
    MODIFIABLE_DATE_FIELDS = [:created_at, :updated_at]

    def initialize(master_populator)
      super(master_populator, :campaign_management_campaign_message_analytics)
    end

    def copy_data
      self.reference.each do |ref_object|
        cma = CampaignManagement::CampaignMessageAnalytics.new.tap do |campaign_message_analytics|
          assign_data(campaign_message_analytics, ref_object)
          campaign_message_analytics.year_month = CampaignManagement::AbstractCampaignMessage.get_analytics_summary_key(self.modify_date(DateTime.strptime(ref_object.year_month, "%Y%m"), "to_time", "delta_month"))
          campaign_message_analytics.campaign_message_id = master_populator.solution_pack_referer_hash["CampaignManagement::AbstractCampaignMessage"][ref_object.campaign_message_id]
        end
        CampaignManagement::CampaignMessageAnalytics.import([cma], validate: false, timestamps: false)
      end
    end
  end
end

