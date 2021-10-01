class RemoveEmailThemeFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :email_theme
  end

  def down
    add_column :programs, :email_theme, :integer
  end
end
