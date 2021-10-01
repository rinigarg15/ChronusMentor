require_relative './../../test_helper.rb'

class UTF8MB4UpgradeTest < ActiveSupport::TestCase

  # Max-limit of indexed varchar column should be <= 191.
  # add_column <table name>, <column_name>, :string, limit: UTF8MB4_VARCHAR_LIMIT
  # t.references <column_name>, polymorphic: { limit: UTF8MB4_VARCHAR_LIMIT }

  # If max-limit of 255 characters is still needed,
  # change column to 'utf8' charset and 'utf8_unicode_ci' collation in the migration.
  # change_column <table name>, <column_name>, "VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"
  def test_indexed_utf8mb4_varchar_columns_should_have_max_limit_191
    connection = ActiveRecord::Base.connection
    database = connection.current_database
    sql = "SELECT I.INDEX_NAME, C.TABLE_NAME, C.COLUMN_NAME, C.COLUMN_TYPE, C.CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.STATISTICS AS I JOIN INFORMATION_SCHEMA.COLUMNS AS C ON I.TABLE_NAME = C.TABLE_NAME AND I.COLUMN_NAME = C.COLUMN_NAME WHERE I.TABLE_SCHEMA = '#{database}' AND I.INDEX_NAME != 'PRIMARY' AND C.TABLE_SCHEMA = '#{database}' AND C.DATA_TYPE = 'varchar' AND C.CHARACTER_SET_NAME = 'utf8mb4' AND C.CHARACTER_MAXIMUM_LENGTH > #{UTF8MB4_VARCHAR_LIMIT} GROUP BY C.COLUMN_NAME, C.TABLE_NAME;"
    result = connection.exec_query(sql).to_a
    assert_empty result, "Max-limit of indexed varchar column should be <= 191."
  end

  def test_problematic_columns_should_be_in_utf8
    migrator = MigrateDBFromUTF8ToUTF8MB4.new
    assert MigrateDBFromUTF8ToUTF8MB4::COLUMNS_TO_RETAIN_IN_UTF8.all? do |column_details|
      table_name, column_names = column_details
      column_charset, column_type = migrator.send :get_column_charset_and_type, table_name, column_names
      column_charset == "utf8" && column_type = "varchar(255)"
    end

    assert MigrateDBFromUTF8ToUTF8MB4::COLUMNS_TO_CHANGE_COLLATION.all? do |column_details|
      column_collation = migrator.send :get_column_collation, column_details[:table_name], column_details[:column_name]
      column_collation == column_details[:collation]
    end
  end
end