class CmMigrateDjsToUserJobsDestroyJobs < ActiveRecord::Migration[4.2]

  def up
    # This could have been part of the previous migration 20140827072842 but ran that already on staging
    # dj_ids = CampaignManagement::UserCampaignMessageJob.where("delayed_job_id IS NOT NULL").pluck(:delayed_job_id)
    # Delayed::Job.where(:id => dj_ids).destroy_all
  end

  def down
  end
end
