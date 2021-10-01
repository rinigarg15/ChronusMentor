class AddAllowMenteeToMenteeMessagingToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_mentee_to_mentee_messaging, :boolean, :default => true, :null => false
  end
end
