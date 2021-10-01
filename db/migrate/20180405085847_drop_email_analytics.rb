class DropEmailAnalytics < ActiveRecord::Migration[4.2]
  def up
    ChronusMigrate.ddl_migration do
      drop_table :email_analytics
    end
  end

  def down
    # Do nothing
  end
end
