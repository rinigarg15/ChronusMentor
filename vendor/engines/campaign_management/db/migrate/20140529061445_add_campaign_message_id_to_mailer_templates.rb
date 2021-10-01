class AddCampaignMessageIdToMailerTemplates < ActiveRecord::Migration[4.2]

  def change
    add_column :mailer_templates, :campaign_message_id, :integer
    add_index :mailer_templates, :campaign_message_id
  end
end