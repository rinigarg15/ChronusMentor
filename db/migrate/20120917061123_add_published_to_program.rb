class AddPublishedToProgram< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :published, :boolean, :default => true
  end
end
