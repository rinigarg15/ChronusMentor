class AddUserJobsToCampaigns < ActiveRecord::Migration[4.2]

  def change
    add_column :cm_campaigns, :user_jobs, :text
  end
end
