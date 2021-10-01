class CreateObjectPermissions< ActiveRecord::Migration[4.2]
  def change
    create_table :object_permissions do |t|
      t.string :name
      t.timestamps null: false
    end
  end
end
