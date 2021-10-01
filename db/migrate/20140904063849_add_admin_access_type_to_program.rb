class AddAdminAccessTypeToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :admin_access_to_mentoring_area, :integer, :default => Program::AdminAccessToMentoringArea::OPEN
  end
end
