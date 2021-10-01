class AddRefObjIdToAbstractCampaign < ActiveRecord::Migration[4.2]

  def change
    add_column :cm_campaigns, :ref_obj_id, :integer
    add_index :cm_campaigns, :ref_obj_id
  end
end
