class AddCampaignMessageIdToMessages < ActiveRecord::Migration[4.2]

  def change
    add_column :messages, :campaign_message_id, :integer
    add_index :messages, :campaign_message_id
  end
end