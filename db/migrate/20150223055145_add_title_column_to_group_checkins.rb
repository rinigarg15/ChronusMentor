class AddTitleColumnToGroupCheckins< ActiveRecord::Migration[4.2]
  def change
    add_column :group_checkins, :title, :string
  end
end
