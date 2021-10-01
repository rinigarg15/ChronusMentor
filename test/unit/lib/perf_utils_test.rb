require_relative './../../test_helper.rb'

class PerfUtilsTest < ActiveSupport::TestCase
  def test_table_for_join
    user_ids = User.first(10).collect(&:id)
    table_name = "test_join_table"
    PerfUtils.table_for_join("table_name", user_ids) do |temp_table|
      assert_equal user_ids, User.joins("INNER JOIN #{temp_table} ON #{temp_table}.id = users.id").pluck(:id)
      table_name = temp_table
    end
    assert_false ActiveRecord::Base.connection.table_exists?(table_name)
  end
end