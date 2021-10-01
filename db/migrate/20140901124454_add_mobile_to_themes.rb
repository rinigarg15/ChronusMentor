class AddMobileToThemes< ActiveRecord::Migration[4.2]
  def change
    add_column :themes, :mobile, :boolean, :default => false
  end
end
