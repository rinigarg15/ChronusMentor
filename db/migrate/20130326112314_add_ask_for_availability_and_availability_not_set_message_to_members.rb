class AddAskForAvailabilityAndAvailabilityNotSetMessageToMembers< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :will_set_availability_slots, :boolean, :default => true
    add_column :members, :availability_not_set_message, :text
	add_column :calendar_settings, :allow_mentor_to_not_set_availability, :boolean, :default => false
  end
end
