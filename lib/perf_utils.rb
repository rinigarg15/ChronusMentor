module PerfUtils
  # Creates a temporary table, inserts the values and executes the block which uses this table.
  def self.table_for_join(table_name, values)
    temp_table = "#{table_name}_#{Time.now.to_i}_#{Thread.current[:meta_request_id].try(:id) || SecureRandom.hex(6)}".tr('-','_').first(64)
    create_table_sql = "CREATE TEMPORARY TABLE IF NOT EXISTS #{temp_table} (id int)"
    ActiveRecord::Base.connection.execute(create_table_sql)
    if values.any?
      insert_sql = "INSERT INTO #{temp_table} (id) VALUES (#{values.join("),(")})"
      ActiveRecord::Base.connection.execute(insert_sql)
    end
    yield(temp_table)
  ensure
    drop_table_sql = "DROP TEMPORARY TABLE #{temp_table}"
    ActiveRecord::Base.connection.execute(drop_table_sql)
  end

  # Get scope joining with temporary table
  def self.scope_with_temp_table(class_name, table_name, column_name)
    class_name.joins("INNER JOIN #{table_name} ON #{table_name}.id = #{class_name.table_name}.#{column_name}")
  end
end