class AddDeltaToMember< ActiveRecord::Migration[4.2]
  def change
    add_column :members, :delta, :boolean, :default => false
  end
end
