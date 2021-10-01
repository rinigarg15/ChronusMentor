class ChangeDefaultValueOfUserJobsCreatedForExistingCampaignMessages < ActiveRecord::Migration[4.2]

  # We are assuming that all the user jobs have been created once for all the existing campaign messages.
  # However there might be campaign messages for which the user jobs have not been created yet.
  def up
    CampaignManagement::AbstractCampaignMessage.update_all(:user_jobs_created => true)
  end

  def down
  end
end


