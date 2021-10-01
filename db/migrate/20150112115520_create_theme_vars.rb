class CreateThemeVars< ActiveRecord::Migration[4.2]
  def change
    add_column :themes, :vars_list, :text
  end
end
