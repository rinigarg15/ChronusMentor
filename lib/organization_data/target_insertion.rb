module OrganizationData
  class TargetInsertion
    def initialize(ids, source_db, target_clone_db, options = {})
      @db_insert_errors = []
      @source_db = source_db
      @target_clone_db = target_clone_db
      @db_objects_collect_file_path = options[:db_file_path] || "#{Rails.root}/tmp/db_objects_#{ids}.json"
    end

    def create_target_clone_db
      ActiveRecord::Base.connection.execute("DROP DATABASE IF EXISTS #{@target_clone_db}")
      ActiveRecord::Base.connection.execute("CREATE DATABASE #{@target_clone_db}")
      copy_source_schema_to_clone_db
    end

    def print_errors
      puts "DB Insert Errors: #{@db_insert_errors}"
    end

    def insert_db_objects
      json_text = File.read(@db_objects_collect_file_path)
      rows = JSON.parse(json_text)
      table_entries = consolidate_rows(rows)
      #Each row will contain model and its ids
      begin
        table_entries.each do |table_name, ids|
          ids.uniq!
          puts "Inserting #{ids} from #{table_name}"
          Array(ids).in_groups_of(5000) do |ids_group|
            ActiveRecord::Base.connection.execute "INSERT INTO #{@target_clone_db}.#{table_name} (SELECT * FROM #{@source_db}.#{table_name} WHERE id IN (#{ids_group.compact.join(',')}));"
          end
        end
      rescue => error
        @db_insert_errors << error.message
      end
    end

    def consolidate_rows(rows)
      table_entries = {}
      rows.each do |row|
        table_name = row[0].constantize.table_name
        table_entries[table_name] =  (table_entries[table_name] || []) + row[1]
      end
      return table_entries
    end

    def copy_source_schema_to_clone_db
      db_config = ActiveRecord::Base.configurations[Rails.env]
      timestamp = Time.now.to_i.to_s
      host_or_socket = db_config.has_key?('host') ? "-h #{db_config['host']}" : "-S #{db_config['socket']}"
      system("mysqldump #{host_or_socket} -u #{db_config['username']} #{'-p' if ENV['DATABASE_PWD'].present?}#{ENV['DATABASE_PWD']} --no-data #{db_config['database']} > /tmp/schema_#{timestamp}.sql")
      system("mysql #{host_or_socket} -u #{db_config['username']} #{'-p' if ENV['DATABASE_PWD'].present?}#{ENV['DATABASE_PWD']} #{@target_clone_db} < /tmp/schema_#{timestamp}.sql")
    end
  end
end