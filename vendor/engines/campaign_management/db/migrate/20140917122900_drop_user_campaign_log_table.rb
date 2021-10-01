class DropUserCampaignLogTable < ActiveRecord::Migration[4.2]

  def up
    drop_table :cm_user_campaign_logs
  end

  def down
    create_table :cm_user_campaign_logs do |t|
      t.belongs_to :campaign
      t.belongs_to :user
      t.string :status
      t.timestamps null: false
    end
    add_index :cm_user_campaign_logs, :campaign_id
    add_index :cm_user_campaign_logs, :user_id

  end
end
