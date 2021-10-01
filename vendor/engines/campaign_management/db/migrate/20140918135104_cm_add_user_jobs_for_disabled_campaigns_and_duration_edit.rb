class CmAddUserJobsForDisabledCampaignsAndDurationEdit < ActiveRecord::Migration[4.2]


  def up
    #On staging we had already run the later migrations which involved removal of the "finished" column from cm_campaign_user_statuses.
    # We later figured out that in order for things to be consistent in production we need to run this migration first. 
    # if column_exists?(:cm_campaign_user_statuses, :finished) 
      # Program.includes(:campaigns => :campaign_messages).select("programs.id").each do |program|
        # program.user_campaigns.each do |campaign|
          #campaign_message = campaign.campaign_messages.first 
          # ideal_ongoing_user_ids = campaign.user_statuses.where(:finished => false).pluck(:user_id).uniq          
          # actual_user_ids = campaign.jobs.pluck(:user_id).uniq
          # user_ids_which_need_fix = ideal_ongoing_user_ids - actual_user_ids
          # user_statuses_scope = campaign.user_statuses.select([:created_at, :user_id]).where(:user_id => user_ids_which_need_fix)
          # params = []
          # user_statuses_scope.each do |user_stat|
            # params << {:user_id => user_stat.user_id, :campaign_message_id => campaign_message.id, :run_at => user_stat.created_at + campaign_message.duration.days}
          # end 
          # create_user_job(params)
        # end
      # end
    # end
  end

  def down
  end

  # def create_user_job(params)
    # begin
      # CampaignManagement::UserCampaignMessageJob.create(params)
    # end
  # end
end