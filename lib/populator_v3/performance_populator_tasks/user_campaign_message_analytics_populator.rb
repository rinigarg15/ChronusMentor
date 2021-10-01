class UserCampaignMessageAnalyticsPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    user_campaign_ids = @program.user_campaigns.pluck(:id)
    user_campaign_message_ids = CampaignManagement::UserCampaignMessage.where(campaign_id: user_campaign_ids).pluck(:id)
    user_campaign_message_analytics_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_campaign_message_ids)
    process_patch(user_campaign_message_ids, user_campaign_message_analytics_hsh) 
  end

  def add_user_campaign_message_analytics(user_campaign_message_ids, count, options = {})
    self.class.benchmark_wrapper "User Campaign Message Analytics" do
      program = options[:program]
      user_ids = program.users.active.pluck(:id)
      temp_user_ids = user_ids.dup
      campaign_messages = CampaignManagement::UserCampaignMessage.where(id: user_campaign_message_ids).to_a
      temp_campaign_messages = campaign_messages * count
      iterator = 0
      start_time = Time.now + rand(1..100).days
      CampaignManagement::CampaignMessageAnalytics.populate(user_campaign_message_ids.size * count, :per_query => 10_000) do |campaign_message_analytics|
        cm_message  = temp_campaign_messages.shift
        campaign_message_analytics.campaign_message_id = cm_message.id
        campaign_message_analytics.event_type = [CampaignManagement::EmailEventLog::Type::CLICKED, CampaignManagement::EmailEventLog::Type::OPENED, CampaignManagement::EmailEventLog::Type::DROPPED, CampaignManagement::EmailEventLog::Type::BOUNCED, CampaignManagement::EmailEventLog::Type::SPAMMED, CampaignManagement::EmailEventLog::Type::OPENED, CampaignManagement::EmailEventLog::Type::DELIVERED, CampaignManagement::EmailEventLog::Type::DELIVERED, CampaignManagement::EmailEventLog::Type::DELIVERED, CampaignManagement::EmailEventLog::Type::DELIVERED].sample
        campaign_message_analytics.year_month = (start_time + iterator.months).strftime('%Y%m').to_s
        campaign_message_analytics.event_count = rand(0..5000)
        campaign_message_analytics.created_at = [Time.now - rand(1..100).days, cm_message.created_at].max
        iterator += 1
        self.dot
      end
      self.class.display_populated_count(user_campaign_message_ids.size * count, "User Campaign Message Analytics")
    end
  end

  def remove_user_campaign_message_analytics(user_campaign_message_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User Campaign Message Analytics................" do
      campaign_message_analytics_ids = CampaignManagement::CampaignMessageAnalytics.where(:campaign_message_id => user_campaign_message_ids).select([:id, :campaign_message_id]).group_by(&:campaign_message_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      CampaignManagement::CampaignMessageAnalytics.where(:id => campaign_message_analytics_ids).destroy_all
      self.class.display_deleted_count(user_campaign_message_ids.size * count, "User Campaign Message Analytics")
    end
  end
end