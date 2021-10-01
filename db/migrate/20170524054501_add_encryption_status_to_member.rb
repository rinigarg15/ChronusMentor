class AddEncryptionStatusToMember< ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :members do |m|
        # A flag to indicate the type of encryption applied to member password. By default we need all the newly created members to have sha2 password.
        m.add_column :encryption_type, "VARCHAR(25) DEFAULT 'sha2'"
        m.change_column(:crypted_password, "VARCHAR(255)")
      end
    end
    # At present (Before migration) all the members passwords are sha1 encrypted.
    execute "UPDATE members SET encryption_type = 'sha1'"
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :members do |m|
        m.change_column(:crypted_password, "VARCHAR(40)")
        m.remove_column :encryption_type
      end
    end
  end
end
