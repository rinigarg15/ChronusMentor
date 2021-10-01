class UserCampaignStatusPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    user_campaign_ids = @program.user_campaigns.pluck(:id)
    user_campaign_status_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_campaign_ids)
    process_patch(user_campaign_ids, user_campaign_status_hsh) 
  end

  def add_user_campaign_statuses(user_campaign_ids, count, options = {})
    self.class.benchmark_wrapper "User Campaign Status" do
      program = options[:program]
      user_ids = program.users.active.pluck(:id)
      temp_user_ids = user_ids.dup
      user_campaigns = CampaignManagement::UserCampaign.where(id: user_campaign_ids).to_a
      temp_user_campaigns = user_campaigns * count
      CampaignManagement::UserCampaignStatus.populate(user_campaign_ids.size * count, :per_query => 10_000) do |user_status|
        temp_user_ids = user_ids.dup if temp_user_ids.blank?
        user_campaign = temp_user_campaigns.shift
        user_status.campaign_id = user_campaign.id
        user_status.abstract_object_id = temp_user_ids.shift
        user_status.created_at = [Time.now - rand(1..100).days, user_campaign.created_at].max
        self.dot
      end
      self.class.display_populated_count(user_campaign_ids.size * count, "User Campaign Status")
    end
  end

  def remove_user_campaign_statuses(user_campaign_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User Campaign status................" do
      user_campaign_status_ids = CampaignManagement::UserCampaignStatus.where(:campaign_id => user_campaign_ids).select([:id, :campaign_id]).group_by(&:campaign_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      CampaignManagement::UserCampaignStatus.where(:id => user_campaign_status_ids).destroy_all
      self.class.display_deleted_count(user_campaign_ids.size * count, "User Campaign Status")
    end
  end
end