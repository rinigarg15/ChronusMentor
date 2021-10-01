class CreateCampaignMessageAnalytics < ActiveRecord::Migration[4.2]

  def change
    create_table :cm_campaign_message_analytics do |t|
      t.belongs_to :campaign_message, null: false
      t.string :year_month, limit: UTF8MB4_VARCHAR_LIMIT
      t.integer :event_type
      t.integer :count, :default => 1

      t.timestamps null: false
    end
    add_index :cm_campaign_message_analytics, [:campaign_message_id, :year_month, :event_type], :unique => true, :name => 'index_campaign_analytics_on_cm_id_and_ym_and_event_type'
  end
end
