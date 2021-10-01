class RemoveActivityCountFromGroups< ActiveRecord::Migration[4.2]
  def up
  	remove_column :groups, :activity_count
  end

  def down
  	add_column :groups, :activity_count, :integer
  end
end
