class AddContactNameUrlToPrograms< ActiveRecord::Migration[4.2]
  def change
    add_column :programs, :contact_name, :string
    add_column :programs, :contact_url, :text
  end
end
