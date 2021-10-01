class AddAllowUserToSendMessageOutsideMentoringArea< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :allow_user_to_send_message_outside_mentoring_area, :boolean, :default => true
    Program.all.each do |program|
      program.update_attributes!(:allow_user_to_send_message_outside_mentoring_area => (program.allow_mentee_to_mentee_messaging && program.unconnected_mentee_can_contact_mentor))
    end
    remove_column :programs, :unconnected_mentee_can_contact_mentor
    remove_column :programs, :allow_mentee_to_mentee_messaging
  end
 
  def down
    remove_column :programs, :allow_user_to_send_message_outside_mentoring_area
    add_column :programs, :unconnected_mentee_can_contact_mentor, :boolean, :default => true
    add_column :programs, :allow_mentee_to_mentee_messaging, :boolean, :default => true
  end
end