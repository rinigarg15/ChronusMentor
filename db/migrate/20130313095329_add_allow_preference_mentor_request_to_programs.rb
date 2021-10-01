class AddAllowPreferenceMentorRequestToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_preference_mentor_request, :boolean, :default => true
  end
end
