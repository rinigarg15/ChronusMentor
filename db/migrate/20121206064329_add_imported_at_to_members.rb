class AddImportedAtToMembers< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :imported_at, :datetime
  end
end
