class RemoveGappDomainFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :gapp_domain
  end

  def down
    add_column :programs, :gapp_domain, :string
    add_index :programs, :gapp_domain
  end
end
