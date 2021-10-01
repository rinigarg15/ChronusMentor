class ChangeCampaignsUserJobsField < ActiveRecord::Migration[4.2]

  def up
    change_column :cm_campaigns, :user_jobs, :mediumtext
  end

  def down
    change_column :cm_campaigns, :user_jobs, :text
  end
end
