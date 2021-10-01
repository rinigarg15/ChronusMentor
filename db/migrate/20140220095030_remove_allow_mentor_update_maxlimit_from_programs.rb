class RemoveAllowMentorUpdateMaxlimitFromPrograms< ActiveRecord::Migration[4.2]
  def change
    remove_column :programs, :allow_mentor_update_maxlimit
  end

end
