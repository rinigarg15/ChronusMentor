class DropNotNullConstraintsOnRoleResources< ActiveRecord::Migration[4.2]
  def up
  	ActiveRecord::Base.connection.execute("ALTER TABLE role_resources MODIFY resource_id INT(11)")
  end

  def down
  	ActiveRecord::Base.connection.execute("ALTER TABLE role_resources MODIFY resource_id INT(11) NOT NULL")
  end
end
