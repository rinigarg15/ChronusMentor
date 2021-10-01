class AddDescriptionToSection< ActiveRecord::Migration[4.2]
  def change
    add_column :sections, :description, :text
  end
end
