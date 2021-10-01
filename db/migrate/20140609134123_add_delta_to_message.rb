class AddDeltaToMessage< ActiveRecord::Migration[4.2]
  def change
    add_column :messages, :delta, :boolean, default: false
    add_index  :messages, :delta
  end
end
