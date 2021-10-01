class UserCampaignMessageJobPopulator < PopulatorTask

  def patch(options = {})
    return unless @options[:common]["campaign_management_enabled?"]
    user_campaign_ids = @program.user_campaigns.pluck(:id)
    user_campaign_message_ids = CampaignManagement::UserCampaignMessage.where(campaign_id: user_campaign_ids).pluck(:id)
    user_campaign_message_jobs_hsh = get_children_hash(nil, @options[:args]["model"]||@node, @foreign_key, user_campaign_message_ids)
    process_patch(user_campaign_message_ids, user_campaign_message_jobs_hsh) 
  end

  def add_user_campaign_message_jobs(user_campaign_message_ids, count, options = {})
    self.class.benchmark_wrapper "User Campaign Message Job" do
      program = options[:program]
      user_ids = program.users.active.pluck(:id)
      temp_user_ids = user_ids.dup
      campaign_messages = CampaignManagement::UserCampaignMessage.where(id: user_campaign_message_ids).to_a
      temp_campaign_messages = campaign_messages * count
      CampaignManagement::UserCampaignMessageJob.populate(user_campaign_message_ids.size * count, :per_query => 10_000) do |user_job|
        message = temp_campaign_messages.shift
        temp_user_ids = user_ids.dup if temp_user_ids.blank?
        user_job.campaign_message_id = message.id
        user_job.abstract_object_id = temp_user_ids.shift
        user_job.created_at = [Time.now - rand(1..100).days, message.created_at].max
        user_job.run_at = user_job.created_at + rand(1..100).days
        user_job.failed = [true, true, true, true, true, true, true, true, true, true, false].sample
        self.dot
      end
      self.class.display_populated_count(user_campaign_message_ids.size * count, "User Campaign Message Job")
    end
  end

  def remove_user_campaign_message_jobs(user_campaign_message_ids, count, options = {})
    self.class.benchmark_wrapper "Removing User Campaign Message Jobs................" do
      user_campaign_message_job_ids = CampaignManagement::UserCampaignMessageJob.where(:campaign_message_id => user_campaign_message_ids).select([:id, :campaign_message_id]).group_by(&:campaign_message_id).map{|a| a[1].last(count)}.flatten.collect(&:id)
      CampaignManagement::UserCampaignMessageJob.where(:id => user_campaign_message_job_ids).destroy_all
      self.class.display_deleted_count(user_campaign_message_ids.size * count, "User Campaign Message Job")
    end
  end
end