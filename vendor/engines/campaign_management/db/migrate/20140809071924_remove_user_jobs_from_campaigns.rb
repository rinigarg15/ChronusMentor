class RemoveUserJobsFromCampaigns < ActiveRecord::Migration[4.2]

  def change
    remove_column :cm_campaigns, :user_jobs
  end
end
