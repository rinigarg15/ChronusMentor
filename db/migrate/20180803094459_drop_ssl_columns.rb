class DropSslColumns < ActiveRecord::Migration[5.1]
  def up
    ChronusMigrate.ddl_migration do
      Lhm.change_table :programs do |r|
        r.remove_column :ssl_only
        r.remove_column :ssl_certificate_available
      end
    end
  end

  def down
    ChronusMigrate.ddl_migration do
      Lhm.change_table :programs do |r|
        r.add_column :ssl_only, "tinyint(1) DEFAULT '0'"
        r.add_column :ssl_certificate_available, "tinyint(1) DEFAULT '0'"
      end
    end
  end
end
