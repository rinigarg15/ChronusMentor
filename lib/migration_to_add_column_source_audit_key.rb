class MigrationToAddColumnSourceAuditKey

  # LHM requires primary_key field in the table for processing. `schema_migrations` table doesn't have a primary key.
  TABLES_TO_BE_UPDATED_WITHOUT_LHM = ["schema_migrations"]

  def initialize(options={})
    @connection = ActiveRecord::Base.connection
    @database = @connection.current_database
    @table_names = options[:table_names].presence
  end

  def add_column_migration
    column_migration("add", "Migrating")
  end

  def remove_column_migration
    column_migration("remove", "Rolling back")
  end

  def switch_tables
    tables_to_switch = get_table_names
    return if tables_to_switch.blank?

    start_time = Time.now
    tables_to_switch.each_with_index do |table_name, index|
      origin = Lhm::Table.parse(table_name, @connection)
      destination = Lhm::Table.parse(origin.destination_name, @connection)
      migration = Lhm::Migration.new(origin, destination, [], [])
      Lhm::Entangler.new(migration, @connection).after(true)
      Lhm::AtomicSwitcher.new(migration, @connection).run
      say "." if ((index + 1) % 10).zero?
    end
    say "Completed in #{Time.now - start_time} secs"
  end

  def list_tables_without_column_source_audit_key
    result = @connection.exec_query("SELECT table_name FROM INFORMATION_SCHEMA.TABLES T WHERE T.table_schema = '#{@database}' AND T.TABLE_TYPE = 'BASE TABLE' AND NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.COLUMNS C WHERE C.TABLE_SCHEMA = T.TABLE_SCHEMA AND C.TABLE_NAME = T.TABLE_NAME AND C.COLUMN_NAME = '#{SOURCE_AUDIT_KEY}')")
    tables_list = result.rows.try(:flatten)
    tables_list.reject! { |table_name| table_name.starts_with? "lhm" }
    tables_list -= TABLES_TO_BE_UPDATED_WITHOUT_LHM
    if tables_list.present?
      say "Following tables doesn't have column source_audit_key"
      say tables_list.join(",")
    else
      say "All the tables have column source_audit_key"
    end
  end

  def get_table_names
    @table_names = (@table_names || @connection.tables).reject { |table_name| table_name.starts_with? "lhm" }
    @table_names -= TABLES_TO_BE_UPDATED_WITHOUT_LHM
  end

private
  def say(msg)
    puts msg
  end

  def column_migration(action, message)
    table_names = get_table_names
    return if table_names.blank?
    csv_path = "/tmp/#{action}_source_audit_key_column_migration_time_taken_#{Time.now.to_i}.csv"
    CSV.open(csv_path, "w+") do |csv|
      table_names.each_with_index do |table_name, index|
        say "#{index + 1}. #{message} #{table_name}...".green
        time_then = Time.now
        Lhm.change_table table_name.to_sym do |lhm_table|
          case action
          when "add"
            lhm_table.add_column SOURCE_AUDIT_KEY.to_sym, "VARCHAR(191)"
          when "remove"
            lhm_table.remove_column SOURCE_AUDIT_KEY.to_sym
          end
        end
        time_now = Time.now
        csv << [table_name, (time_now - time_then).round(2).to_s]
      end
    end
  end

end
