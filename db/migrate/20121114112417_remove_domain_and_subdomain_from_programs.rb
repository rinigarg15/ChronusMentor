class RemoveDomainAndSubdomainFromPrograms< ActiveRecord::Migration[4.2]
  def up
    remove_column :programs, :domain
    remove_column :programs, :subdomain
  end

  def down
    add_column :programs, :domain, :string
    add_column :programs, :subdomain, :string
  end
end
