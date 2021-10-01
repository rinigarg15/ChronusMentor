class CreateCmCampaignEmails < ActiveRecord::Migration[4.2]

  def change
    create_table :cm_campaign_emails do |t|
      t.belongs_to :campaign_message, :null => false

      # The below will just be program invitations for the time being, but it can be extended to any campaign base objects whose emails are not stored in the DB and whose analytics have to be captured!
      t.integer :abstract_object_id, :null => false
      t.text :subject
      t.text :source
      t.timestamps null: false
    end
  end
end
