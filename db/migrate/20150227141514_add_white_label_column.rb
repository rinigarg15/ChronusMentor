class AddWhiteLabelColumn< ActiveRecord::Migration[4.2]
  def up
    add_column :programs, :white_label, :boolean, :default => false
    add_column :programs, :favicon_link, :text, :default => nil
  end

  def down
  	remove_column :programs, :white_label
    remove_column :programs, :favicon_link
  end
end
