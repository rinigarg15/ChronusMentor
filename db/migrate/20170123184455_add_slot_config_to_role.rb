class AddSlotConfigToRole< ActiveRecord::Migration[4.2]
  def change
    add_column :roles, :slot_config, :integer
  end
end
