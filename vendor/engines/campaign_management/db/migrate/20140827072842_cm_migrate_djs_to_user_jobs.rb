class CmMigrateDjsToUserJobs < ActiveRecord::Migration[4.2]

  def up
    # CampaignManagement::UserCampaignMessageJob.all.each do |user_job|
     # begin        
      #  user_job.run_at = Delayed::Job.find(user_job.delayed_job_id).run_at
      # rescue ActiveRecord::RecordNotFound
       # user_job.failed = true
       # user_job.run_at = Time.now
      # end
      # user_job.save!
    # end
  end

  def down
  end
end
