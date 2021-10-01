class AddColumnSubKeyToAdminViewColumns< ActiveRecord::Migration[4.2]
  def change
    add_column :admin_view_columns, :column_sub_key, :string
  end
end
