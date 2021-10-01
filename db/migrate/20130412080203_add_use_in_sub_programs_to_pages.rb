class AddUseInSubProgramsToPages< ActiveRecord::Migration[4.2]
  def change
    add_column :pages, :use_in_sub_programs, :boolean, default: false
  end
end
