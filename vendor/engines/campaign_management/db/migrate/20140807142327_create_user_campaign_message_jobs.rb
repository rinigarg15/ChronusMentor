class CreateUserCampaignMessageJobs < ActiveRecord::Migration[4.2]

  def change
    create_table :cm_campaign_message_user_jobs do |t|
      t.integer :campaign_message_id
      t.integer :delayed_job_id
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
