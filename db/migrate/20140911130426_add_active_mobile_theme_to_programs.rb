class AddActiveMobileThemeToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :active_mobile_theme, :integer
  end
end
