class AddVersionToGroups< ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :version, :integer, default: 1
  end
end
