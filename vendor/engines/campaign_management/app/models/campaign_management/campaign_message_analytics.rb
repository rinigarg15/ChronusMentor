class CampaignManagement::CampaignMessageAnalytics < ActiveRecord::Base
  self.table_name = "cm_campaign_message_analytics"

  belongs_to :campaign_message,
             :foreign_key => "campaign_message_id",
             :class_name => "CampaignManagement::AbstractCampaignMessage",
             :inverse_of => :campaign_message_analyticss

  validates_uniqueness_of :campaign_message_id, :scope => [:event_type, :year_month]

  validates :campaign_message_id, :year_month, :event_count, presence: true
  validates :event_type, presence: true, inclusion: { :in => CampaignManagement::EmailEventLog::Type.all}



  default_scope -> { order('cm_campaign_message_analytics.created_at DESC') }

  def self.add_to_campaign_message_analytics(campaign_message, key, event_type)
    campaign_analytics_entry = campaign_message.campaign_message_analyticss.where(:year_month => key, :event_type => event_type).first

    if campaign_analytics_entry
      campaign_analytics_entry.with_lock do
        campaign_analytics_entry.event_count += 1
        campaign_analytics_entry.save!
      end
    else
      campaign_message.campaign_message_analyticss.create!(:year_month => key, :event_type => event_type)
    end
  end

end
