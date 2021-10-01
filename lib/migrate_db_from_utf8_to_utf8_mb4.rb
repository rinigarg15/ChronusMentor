class MigrateDBFromUTF8ToUTF8MB4

  # utf8mb4 tables can index only first 191 characters. The following columns had data more than 191 characters when the rake task was run.
  # Hence these columns were retained in utf8.
  COLUMNS_TO_RETAIN_IN_UTF8 = {
    "locations" => ["full_address"],
    "educations" => ["school_name", "major"],
    "experiences" => ["job_title", "company"]
  }

  # To handle 20160707130717_change_collation_for_tag_names.acts_as_taggable_on_engine.rb
  COLUMNS_TO_CHANGE_COLLATION = [
    { table_name: "tags", column_name: "name", type: "varchar(191)", charset: "utf8mb4", collation: "utf8mb4_bin" }
  ]

  # LHM requires primary_key field in the table for processing. `schema_migrations` table doesn't have a primary key.
  TABLES_TO_BE_UPDATED_WITHOUT_LHM = ["schema_migrations"]

  def initialize(options = {})
    @connection = ActiveRecord::Base.connection
    @database = @connection.current_database
    @charset = @connection.instance_values["config"][:encoding]
    @collation = @connection.instance_values["config"][:collation]
    @display_progress = !!options[:display_progress]
    @migrate_problematic_columns_only = !!options[:migrate_problematic_columns_only]
    @utf8_table_names_for_migration = []
    @tables_to_switch = []
    @change_varchar_columns = {}
    @change_text_columns = {}
    @additional_queries = {}
    @errors = []
    @csv_file_path = "/tmp/charset_migration_time_taken_#{Time.now.to_i}.csv"
    @error_log_file_path = "/tmp/charset_migration_errors_#{Time.now.to_i}.txt"
  end

  def migrate
    populate_queries_for_utf8mb4_upgrade unless @migrate_problematic_columns_only
    populate_additional_queries_to_retain_columns_in_utf8
    populate_additional_queries_to_change_column_collations
    table_names_to_migrate = @migrate_problematic_columns_only ? COLUMNS_TO_RETAIN_IN_UTF8.keys : @utf8_table_names_for_migration
    migrate_tables(table_names_to_migrate)
    log_migration_errors unless @migrate_problematic_columns_only
    display_progress "\nTask complete at: #{Time.now}"
    return @tables_to_switch
  end

  def switch_tables(tables_to_switch)
    return if tables_to_switch.blank?

    start_time = Time.now
    tables_to_switch -= TABLES_TO_BE_UPDATED_WITHOUT_LHM
    tables_to_switch.each_with_index do |table_name, index|
      origin = Lhm::Table.parse(table_name, @connection)
      destination = Lhm::Table.parse(origin.destination_name, @connection)
      migration = Lhm::Migration.new(origin, destination, [], [])
      Lhm::Entangler.new(migration, @connection).after(true)
      Lhm::AtomicSwitcher.new(migration, @connection).run
      display_progress "." if ((index + 1) % 10).zero?
    end
    display_progress "Completed in #{Time.now - start_time} secs"
  end

  private

  def populate_queries_for_utf8mb4_upgrade
    @utf8_table_names_for_migration = get_utf8_table_names
    display_progress(@utf8_table_names_for_migration.present? ? "Identifying columns to be updated #{Time.now}" : "Already upgraded to utf8mb4")
    @utf8_table_names_for_migration.each_with_index do |table_name, index|
      columns = @connection.columns(table_name)
      indexes_in_table = @connection.indexes(table_name)
      max_lengths_hash = indexes_in_table.present? ? generate_max_lengths_hash(table_name, columns.collect(&:name)) : {}
      columns.each { |column| populate_columns_to_be_updated(column, table_name, indexes_in_table, max_lengths_hash) }
      display_progress "." if ((index + 1) % 10).zero?
    end
  end

  def generate_max_lengths_hash(table_name, column_names)
    max_length_query_phrase = column_names.collect { |column_name| "MAX(LENGTH(#{@connection.quote_column_name(column_name)})) as #{column_name}_max_length" }.join(", ")
    @connection.exec_query("SELECT #{max_length_query_phrase} FROM #{@connection.quote_table_name(table_name)};").to_hash.first
  end

  def populate_columns_to_be_updated(column, table_name, indexes_in_table, max_lengths_hash)
    column_name = column.name
    return if COLUMNS_TO_RETAIN_IN_UTF8.keys.include?(table_name) && COLUMNS_TO_RETAIN_IN_UTF8[table_name].include?(column_name)
    column_type = column.sql_type
    column_limit = column.limit
    column_indexes = get_indexes_for_column(indexes_in_table, column_name)
    longest_element_length = max_lengths_hash["#{column.name}_max_length"]
    # utf8mb4 tables can index only first 191 characters of varchar/text column. Hence setting limits to 191.
    if column_type =~ /^varchar/ && column_indexes.present? && column_limit > UTF8MB4_VARCHAR_LIMIT
      if longest_element_length.to_i <= UTF8MB4_VARCHAR_LIMIT
        @change_varchar_columns[table_name] ||= []
        @change_varchar_columns[table_name] << [:change_column, [table_name, column_name, :string, limit: UTF8MB4_VARCHAR_LIMIT]]
      else
        @errors << "Column ignored - table_name: #{table_name}, field: #{column_name}, longest_length: #{longest_element_length}"
      end
    # When table is altered there is a possibility that Text columns are upgraded to next higher limit(MediumText, LargeText, etc). Hence resetting the original limit
    # More info: https://dev.mysql.com/doc/refman/5.7/en/alter-table.html#alter-table-character-set
    elsif column_type =~ /^text/
      @change_text_columns[table_name] ||= []
      @change_text_columns[table_name] << [:change_column, [table_name, column_name, :text, limit: column_limit]]
    end
  end

  def get_indexes_for_column(indexes_in_table, column_name)
    indexes_in_table.collect do |index|
      { index_name: index.name, index_columns: index.columns } if index.columns.include?(column_name)
    end.compact.flatten
  end

  def populate_additional_queries_to_retain_columns_in_utf8
    COLUMNS_TO_RETAIN_IN_UTF8.each_pair do |table_name, column_names|
      indexes_in_table = @connection.indexes(table_name)
      create_column_indexes_sql, drop_column_indexes_sql = create_drop_indexes_sql(indexes_in_table, column_names)
      switch_back_to_utf8_sql = varchar_utf8_sql(table_name, column_names)
      next unless retaining_columns_in_utf8_needed?(table_name, column_names)
      @additional_queries[table_name] ||= []
      # When the table charset is upgraded to utf8mb4, all the varchar/text column charsets of the table upgrades to utf8mb4 and their index length implicitly decreases to 191.
      # Even after the varchar fields are switched back to utf8, the index length remains the same 191 (Not changed to 255).
      # So we explicitly recreate index after converting to utf8. For better performance, indexes are dropped before switching back.
      @additional_queries[table_name] += [drop_column_indexes_sql, switch_back_to_utf8_sql, create_column_indexes_sql]
    end
  end

  def create_drop_indexes_sql(indexes_in_table, column_names)
    create_indexes_sqls = []
    drop_indexes_sqls = []
    column_names.each do |column_name|
      get_indexes_for_column(indexes_in_table, column_name).each do |index_name_columns_hash|
        create_indexes_sqls << "ADD INDEX #{index_name_columns_hash[:index_name]} (#{index_name_columns_hash[:index_columns].join(", ")})"
        drop_indexes_sqls << "DROP INDEX #{index_name_columns_hash[:index_name]}"
      end
    end
    [create_indexes_sqls.uniq.join(", "), drop_indexes_sqls.uniq.join(", ")]
  end

  def varchar_utf8_sql(table_name, column_names)
    operations = column_names.collect do |column_name|
      [:change_column, [table_name.to_sym, column_name, "VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_unicode_ci"]]
    end
    generate_sql(operations)
  end

  def generate_sql(operations)
    operations.map do |command, args|
      table, arguments = args.shift, args
      method = :"#{command}_sql"
      if @connection.respond_to?(method, true)
        @connection.send(method, table, *arguments)
      else
        raise "Unknown method called: #{method}(#{arguments.inspect})"
      end
    end.flatten.join(", ")
  end

  def retaining_columns_in_utf8_needed?(table_name, column_names)
    column_charset, column_type = get_column_charset_and_type(table_name, column_names)
    @utf8_table_names_for_migration.include?(table_name) || (column_charset != "utf8" || column_type != "varchar(255)")
  end

  def populate_additional_queries_to_change_column_collations
    COLUMNS_TO_CHANGE_COLLATION.each do |column_details|
      table_name = column_details[:table_name]
      column_name = column_details[:column_name]
      next unless collation_change_needed?(table_name, column_name, column_details[:collation])
      query = generate_sql([[:change_column, [table_name, column_name, "#{column_details[:type]} CHARACTER SET #{column_details[:charset]} COLLATE #{column_details[:collation]}"]]])
      @additional_queries[table_name] ||= []
      @additional_queries[table_name] << query
    end
  end

  def collation_change_needed?(table_name, column_name, new_collation)
    get_column_collation(table_name, column_name) != new_collation
  end

  def migrate_tables(table_names)
    display_progress("\nChanging charsets of tables and db #{Time.now}") if table_names.present?
    CSV.open(@csv_file_path, "w+") do |csv|
      table_names.each_with_index do |table_name, index|
        display_progress "#{index + 1}. Migrating #{table_name}...".green
        time_then = Time.now

        queries = []
        queries << generate_sql(@change_varchar_columns[table_name]) if @change_varchar_columns[table_name].present?
        queries << "CONVERT TO CHARACTER SET '#{@charset}' COLLATE '#{@collation}';" if @utf8_table_names_for_migration.present?
        queries << generate_sql(@change_text_columns[table_name]) if @change_text_columns[table_name].present?
        queries += @additional_queries[table_name] if @additional_queries[table_name].present?
        execute_alter_table_queries(table_name, queries) if queries.present?

        time_now = Time.now
        csv << [table_name, (time_now - time_then).round(2).to_s]
      end
    end
    @connection.execute("ALTER DATABASE `#{@database}` CHARACTER SET = '#{@charset}' COLLATE = '#{@collation}';") if @utf8_table_names_for_migration.present?
  end

  def execute_alter_table_queries(table_name, queries)
    if TABLES_TO_BE_UPDATED_WITHOUT_LHM.include?(table_name)
      queries.each { |query| @connection.execute("ALTER TABLE #{@connection.quote_table_name(table_name)} #{query}") }
    else
      begin
        Lhm.change_table table_name.to_sym do |lhm_table|
          queries.each { |query| lhm_table.ddl("ALTER TABLE #{@connection.quote_table_name(lhm_table.name)} #{query}") }
        end
        @tables_to_switch << table_name
      rescue => ex
        @errors << "#{table_name}: #{ex.message}"
      end
    end
  end

  def get_utf8_table_names
    # Excludes tables created by LHM gem.
    @connection.exec_query("SELECT T.table_name FROM information_schema.`Tables` T INNER JOIN information_schema.`COLLATION_CHARACTER_SET_APPLICABILITY` CCSA ON CCSA.collation_name = T.table_collation WHERE T.table_schema = '#{@database}' AND  CCSA.character_set_name != '#{@charset}' AND T.table_name NOT LIKE 'lhm%';").rows.flatten
  end

  def get_column_collation(table_name, column_name)
    @connection.exec_query("SELECT collation_name FROM information_schema.`COLUMNS` WHERE table_schema = '#{@database}' AND table_name = '#{table_name}' AND column_name = '#{column_name}';").rows.flatten.first
  end

  def get_column_charset_and_type(table_name, column_names)
    quoted_column_names = column_names.collect { |column_name| "'#{column_name}'" }.join(", ")
    @connection.exec_query("SELECT DISTINCT character_set_name, column_type FROM information_schema.`COLUMNS` WHERE table_schema = '#{@database}' AND table_name = '#{table_name}' AND column_name IN (#{quoted_column_names});").rows.flatten
  end

  def log_migration_errors
    File.open(@error_log_file_path, "w") { |file| file.write(@errors.join("\n"))}
  end

  def display_progress(message)
    puts message if @display_progress
  end
end