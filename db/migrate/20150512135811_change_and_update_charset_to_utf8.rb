class ChangeAndUpdateCharsetToUtf8< ActiveRecord::Migration[4.2]
  def up
    # DB will be by default created in utf8mb4. Hence commenting out for future reference
    #
    #
    # database = ActiveRecord::Base.connection.instance_values["config"][:database]
    # execute "ALTER DATABASE #{database} CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
    # tables = ActiveRecord::Base.connection.tables
    # tables.each do |table|
    #   execute "ALTER TABLE #{table} CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
    #   execute "ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
    # end
  end

  def down
  end
end
