class AddLoginCountToConnectionMemberships< ActiveRecord::Migration[4.2]
  def change
    add_column :connection_memberships, :login_count, :integer, :default => 0
  end
end
