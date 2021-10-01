class AddIndexToCreatedAtForAdminMessage < ActiveRecord::Migration[4.2]

  def change
    add_index :messages, :created_at
  end
end
