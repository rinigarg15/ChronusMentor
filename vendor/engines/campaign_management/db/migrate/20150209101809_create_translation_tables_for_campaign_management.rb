class CreateTranslationTablesForCampaignManagement < ActiveRecord::Migration[4.2]
  def up
    CampaignManagement::AbstractCampaign.create_translation_table!({
      :title => :string
    }, {
      :migrate_data => true
    })
  end

  def down
    CampaignManagement::AbstractCampaign.drop_translation_table! :migrate_data => true
  end
end
