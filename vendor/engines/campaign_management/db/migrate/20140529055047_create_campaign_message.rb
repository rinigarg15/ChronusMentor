class CreateCampaignMessage < ActiveRecord::Migration[4.2]

  def change
    create_table :cm_campaign_messages do |t|
      t.belongs_to :campaign, null: false
      t.integer :sender_id
      t.integer :duration
      t.datetime :created_at
      t.datetime :updated_at
      t.string SOURCE_AUDIT_KEY.to_sym, :limit => UTF8MB4_VARCHAR_LIMIT

    end
    add_index :cm_campaign_messages, :campaign_id
  end
end