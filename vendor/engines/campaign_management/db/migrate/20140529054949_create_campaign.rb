class CreateCampaign < ActiveRecord::Migration[4.2]

  def change
    create_table :cm_campaigns do |t|
      t.belongs_to :program, null: false
      t.string :title
      t.integer :owner_id
      t.integer :state, default: CampaignManagement::AbstractCampaign::STATE::STOPPED, null: false
      t.text :trigger_params
      t.datetime :created_at
      t.datetime :updated_at
      t.string SOURCE_AUDIT_KEY.to_sym, :limit => UTF8MB4_VARCHAR_LIMIT
    end
    add_index :cm_campaigns, :program_id
  end
end