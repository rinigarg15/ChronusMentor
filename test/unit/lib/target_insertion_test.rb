require_relative './../../test_helper.rb'

class TargetInsertionTest < ActiveSupport::TestCase

  def test_organization_insertion
    target_insertion = OrganizationData::TargetInsertion.new("", ActiveRecord::Base.connection.current_database, "target_db", db_file_path: "#{Rails.root}/test/fixtures/files/target_insertion_db_objects.json")
    ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS target_db")
    ActiveRecord::Base.connection.execute("CREATE DATABASE target_db")
    ActiveRecord::Base.connection.execute("CREATE TABLE target_db.permissions (id INT, name VARCHAR(191), source_audit_key VARCHAR(191), created_at DATETIME, updated_at DATETIME)")
    timestamp_1 = permissions(:permissions_1).created_at
    timestamp_2 = permissions(:permissions_2).created_at
    target_insertion.insert_db_objects
    results = ActiveRecord::Base.connection.exec_query("select * from target_db.permissions")
    assert_equal [[1, "write_article", nil, timestamp_1, timestamp_1], [2, "view_articles", nil, timestamp_2, timestamp_2]], results.rows
    ActiveRecord::Base.connection.execute("DROP DATABASE target_db")
  end
end