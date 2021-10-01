class RemoveContactNameAndUrlFromProgram< ActiveRecord::Migration[4.2]
  def change
    remove_column :programs, :contact_name
    remove_column :programs, :contact_url
  end
end