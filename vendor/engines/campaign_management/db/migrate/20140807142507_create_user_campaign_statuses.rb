class CreateUserCampaignStatuses < ActiveRecord::Migration[4.2]

  def change
    create_table :cm_campaign_user_statuses do |t|
      t.integer :campaign_id
      t.integer :user_id
      t.boolean :finished, :default => false

      t.timestamps null: false
    end
  end
end
