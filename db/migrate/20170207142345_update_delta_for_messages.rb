class UpdateDeltaForMessages< ActiveRecord::Migration[4.2]
  def change
    Scrap.where(:ref_obj_id => nil).update_all("ref_obj_id = group_id, ref_obj_type='Group'")
  end
end
