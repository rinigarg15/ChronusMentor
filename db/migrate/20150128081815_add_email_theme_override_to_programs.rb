class AddEmailThemeOverrideToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :email_theme_override, :string
  end
end
