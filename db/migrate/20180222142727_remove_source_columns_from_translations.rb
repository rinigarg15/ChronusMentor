class RemoveSourceColumnsFromTranslations < ActiveRecord::Migration[5.1]

  TABLE_TRANSLATED_COLUMNS_MAP = {
    "mentoring_model_tasks" => { title: "varchar(255)", description: "text" }
  }

  def up
    ChronusMigrate.ddl_migration do
      TABLE_TRANSLATED_COLUMNS_MAP.each do |table_name, columns|
        Lhm.change_table table_name do |t|
          columns.keys.each do |column_name|
            t.remove_column column_name
          end
        end
      end
    end
   end

  def down
    ChronusMigrate.ddl_migration do
      TABLE_TRANSLATED_COLUMNS_MAP.each do |table_name, columns|
        Lhm.change_table table_name do |t|
          columns.each do |column_name, column_spec|
            t.add_column column_name, column_spec
          end
        end
      end
    end
  end
end

# TABLE_TRANSLATED_COLUMNS_MAP is computed using the below code:

# def get_column_spec_in_sql(column)
#   column_spec_in_sql = "#{column.sql_type}"
#   column_spec_in_sql += " DEFAULT '#{column.default}'" unless column.default.nil?
#   column_spec_in_sql += " NOT NULL" if column.null == false
#   column_spec_in_sql
# end

# ActiveRecord::Base.descendants.select(&:translates?).inject({}) do |translation_map, klass|
#   translation_map[klass.table_name] ||= {}
#   klass.translated_attribute_names.each do |translated_attribute|
#     translation_map[klass.table_name][translated_attribute] ||= get_column_spec_in_sql(klass.columns_hash[translated_attribute.to_s])
#   end
#   translation_map
# end