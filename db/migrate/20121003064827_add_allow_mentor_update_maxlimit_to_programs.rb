class AddAllowMentorUpdateMaxlimitToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :allow_mentor_update_maxlimit, :boolean, :default => true
  end
end
