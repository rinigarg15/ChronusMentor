# InstanceMigrator::OffsetRowSqlGenerator.new.generate(source, target, source_environment, source_seed)
module InstanceMigrator
  class OffsetRowSqlGenerator < SqlGenerator
    # Generate insert sql statements to insert after an offset number in each table to block the inbetween ids.
    def generate_sql
      File.open("#{Rails.root}/tmp/offset_row_insert.sql", 'w')  do |f|
        f.puts generate_max_count_table
        f.puts generate_join_table_for_common_tables

        write_generated_insert_statements_to_file(f, "=")
      end
    end

    def generate_max_count_table
      temp_model_insert_sql = "DROP TABLE IF EXISTS #{self.target}.temp_model_table_map; CREATE TABLE #{self.target}.temp_model_table_map (model_name VARCHAR(191), table_name VARCHAR(191), target_max_id INT, source_max_id INT);"
      insert_sql_values = []
      self.tables.each do |model, table|
        temp_model_insert_sql << "SELECT COALESCE(max(id), 0) + 1 INTO @target_max_#{table}_id FROM #{self.target}.#{table};"
        temp_model_insert_sql << "SELECT max(id) INTO @source_max_#{table}_id FROM #{self.source}.#{table};"
        insert_sql_values << "('#{model}', '#{table}', @target_max_#{table}_id, @source_max_#{table}_id)"
      end

      temp_model_insert_sql << "INSERT into #{self.target}.temp_model_table_map values " + insert_sql_values.join(", ") + ";"
      return temp_model_insert_sql
    end

    def generate_join_table_for_common_tables
      # If there are entries missing in these tables in the target db, we should raise an error. How are we going to do that?
      join_table_command = "DROP TABLE IF EXISTS #{self.target}.temp_common_join_table; CREATE TABLE #{self.target}.temp_common_join_table (table_name VARCHAR(191), source_j_id INT, target_j_id INT);"

      COMMON_TABLES.each do |table_name, column_name|
        join_table_command << generate_join_command(table_name, column_name)
      end
      return join_table_command
    end

    def generate_join_command(table_name, column_name)
      select_stmt = "SELECT '#{table_name}', source_j.id, target_j.id FROM #{self.source}.#{table_name} source_j #{join_condition(table_name, column_name)}"
      join_table_command = "INSERT INTO #{self.target}.temp_common_join_table (#{select_stmt});"
      join_table_command << "DELETE FROM #{self.source}.#{table_name} WHERE id IN (SELECT source_j_id FROM #{self.target}.temp_common_join_table WHERE table_name = '#{table_name}');"
      join_table_command << "INSERT INTO #{self.target}.temp_common_join_table (SELECT '#{table_name}', id, id + @target_max_#{table_name}_id FROM #{self.source}.#{table_name});"
    end


    def join_condition(table_name, column_name)
      join_command = "INNER JOIN #{self.target}.#{table_name} target_j ON source_j.#{column_name} = target_j.#{column_name}"
      join_command << " WHERE source_j.program_id IS NULL AND target_j.program_id IS NULL" if table_name == "themes"
      join_command
    end
  end
end