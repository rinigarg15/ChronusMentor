class RemoveAutoTerminateFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :auto_terminate
  end

  def down
    add_column :programs, :auto_terminate, :boolean, :default => false
  end
end
