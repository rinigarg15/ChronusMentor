class AddCreatorIdColumnToGroups< ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :creator_id, :integer
  end
end
