class AddNotesToGroups< ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :notes, :text
  end
end
