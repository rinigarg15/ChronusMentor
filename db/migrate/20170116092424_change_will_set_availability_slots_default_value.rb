class ChangeWillSetAvailabilitySlotsDefaultValue< ActiveRecord::Migration[4.2]
  def change
    change_column :members, :will_set_availability_slots, :boolean, :default => false
  end
end
