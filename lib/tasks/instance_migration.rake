namespace :instance_migration do

  task :deactivate_org => [:environment] do
    Common::RakeModule::Utils.execute_task do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
      organization.account_name = ENV['ACCOUNT_NAME'] if ENV['ACCOUNT_NAME'].present?
      organization.active = false
      organization.save!
    end
  end

  # bundle exec rake instance_migration:create_clone_db RAILS_ENV=<rails_env> DOMAIN=<domain> SUBDOMAIN=<subdomain> TARGET_CLONE_DB=<target_clone_db> DB_FILE_PATH=<db_file_path> S3_ASSET_FILE_PATH=<s3_asset_file_path> LAST_DJ_ID=<id>
  # bundle exec rake instance_migration:create_clone_db RAILS_ENV=production domain=chrouns.com subdomain=euwalkthrough TARGET_CLONE_DB=euwalkthrough_db DB_FILE_PATH='tmp/db_objects_euwalkthrough_db.json' S3_ASSET_FILE_PATH='tmp/s3_assets_euwalkthrough_db.csv'
  desc "To be run in the source environment. If there are failures, fix them and run the rake once again."
  task :create_clone_db => [:environment] do
    Common::RakeModule::Utils.execute_task do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
      raise "Organization is still active. Please run instance_migration:deactivate_org_and_clear_dj task." if organization.active?
      target_clone_db = ENV["TARGET_CLONE_DB"]
      current_db = Rails.configuration.database_configuration[Rails.env]["database"]
      raise "TARGET_CLONE_DB cannot match database names already present in the database.yml" if Rails.configuration.database_configuration.select{|env| env["database"] == target_clone_db}.present?

      id = organization.id
      #to load all the class paths for getting proper associations
      Rails.application.eager_load!
      parameters = ["Organization", id, {:db_file_path => ENV['DB_FILE_PATH'], :s3_asset_file_path => ENV['S3_ASSET_FILE_PATH'], :operation => OrganizationData::TargetCollection::OPERATION::COLLECT_FOR_INSERT}]
      model_collection = OrganizationData::TargetCollection.new(*parameters)
      model_collection.collect_data
      model_insertion = OrganizationData::TargetInsertion.new(id, current_db, target_clone_db, {:db_file_path => ENV['DB_FILE_PATH']})
      model_insertion.create_target_clone_db
      model_insertion.insert_db_objects
      model_insertion.print_errors
    end
  end

  # bundle exec rake instance_migration:last_entry_migration RAILS_ENV=<rails_env> SOURCE_CLONED_DB=<source_clone_db> SOURCE_ENVIRONMENT=<source_environment>
  # bundle exec rake instance_migration:last_entry_migration RAILS_ENV=production SOURCE_CLONED_DB='basf_p2' SOURCE_ENVIRONMENT='productioneu'
  desc "To be run in the destination environment after copying the cloned db from source RDS to the target RDS. If there are failures, fix them and run the rake once again."
  task :last_entry_migration => [:environment] do
    Common::RakeModule::Utils.execute_task do
      source_cloned_db = ENV["SOURCE_CLONED_DB"]
      current_db = Rails.configuration.database_configuration[Rails.env]["database"]
      source_environment = ENV["SOURCE_ENVIRONMENT"]
      source_seed = Date.today.strftime("%d_%b_%Y")
      InstanceMigrator::OffsetRowSqlGenerator.new(source_cloned_db, current_db, source_environment, source_seed).generate
      script = Rails.root.join("tmp").join("offset_row_insert.sql").read
      STATEMENT_SEPARATOR = ";"

      sql = ActiveRecord::Base.connection()
      sql.execute "SET autocommit=0"
      sql.execute "SET FOREIGN_KEY_CHECKS=0"
      sql.begin_db_transaction
      script.split(STATEMENT_SEPARATOR).each do |stmt|
        next if stmt.chomp.strip.blank?
        sql.execute(stmt.chomp)
      end
      sql.commit_db_transaction
      sql.execute "SET autocommit=1"
      sql.execute "SET FOREIGN_KEY_CHECKS=1"
      puts "SOURCE_SEED: #{source_seed}. Please use this as input for final_migration rake task"
    end
  end

  # bundle exec rake instance_migration:final_migration RAILS_ENV=<rails_env> SOURCE_CLONED_DB=<source_clone_db> SOURCE_ENVIRONMENT=<source_environment> SOURCE_SEED=<source_seed> S3_ASSET_FILE_PATH=<s3_asset_file_path> S3_ACCESS_KEY=<s3_access_key> S3_SECRET_KEY=<s3_Secret_key> S3_SOURCE_REGION=<s3_source_bucket_region> S3_TARGET_REGION=<s3_target_bucket_region> S3_TARGET_BUCKET=<s3_target_bucket_name>
  # bundle exec rake instance_migration:final_migration RAILS_ENV=production domain=chrouns.com subdomain=euwalkthrough SOURCE_CLONED_DB='basf_p2' SOURCE_ENVIRONMENT='productioneu' SOURCE_SEED='21_Apr_2017' S3_ASSET_FILE_PATH='tmp\s3_assets_euwalkthrough_db.csv' S3_ACCESS_KEY="" S3_SECRET_KEY="" S3_SOURCE_REGION="eu-central-1" S3_TARGET_REGION="us-east-1" S3_TARGET_BUCKET="chronus-mentor"
  desc "To be run in the destination environment after running `rake instance_migration:last_entry_migration`. Use the source seed generated in that rake. Copy S3_ASSET_FILE_PATH from source environment to destination environment before running. If there are failures, fix them and use appropriate flags to execute the failed steps and beyond."
  task :final_migration => [:environment] do
    source_cloned_db = ENV["SOURCE_CLONED_DB"]
    current_db = Rails.configuration.database_configuration[Rails.env]["database"]
    source_environment = ENV["SOURCE_ENVIRONMENT"]
    source_seed = ENV["SOURCE_SEED"]
    begin
      DateTime.strptime(source_seed, "%d_%b_%Y")
    rescue
      raise "Please enter SOURCE_SEED in format like 21_Apr_2017"
    end
    s3_asset_file_path = ENV['S3_ASSET_FILE_PATH']
    s3_migrator_options = { access_key: ENV["S3_ACCESS_KEY"], secret_key: ENV["S3_SECRET_KEY"], source_region: ENV["S3_SOURCE_REGION"], target_region: ENV["S3_TARGET_REGION"], target_bucket_name: ENV["S3_TARGET_BUCKET"] }

    sql_generator = InstanceMigrator::SqlGenerator.new(source_cloned_db, current_db, source_environment, source_seed)

    Common::RakeModule::Utils.execute_task(skip_benchmark: true) do
      unless ENV["SKIP_MODEL_MIGRATION"]
        puts "Migrating models ...."
        time_start = Time.now
        sql_generator.generate
        script = Rails.root.join("tmp").join("models.sql").read
        STATEMENT_SEPARATOR = ";"

        sql = ActiveRecord::Base.connection()
        sql.execute "SET autocommit=0"
        sql.execute "SET FOREIGN_KEY_CHECKS=0"
        sql.begin_db_transaction
        script.split(STATEMENT_SEPARATOR).each do |stmt|
          next if stmt.chomp.strip.blank?
          sql.execute(stmt.chomp)
        end
        sql.commit_db_transaction
        sql.execute "SET FOREIGN_KEY_CHECKS=1"
        sql.execute "SET autocommit=1"
        puts "Time taken for model migration: #{Time.now - time_start}"
      end

      unless ENV["SKIP_YAML_MIGRATION"]
        puts "Migrating YAML columns ...."
        time_start = Time.now
        yaml_migrator = InstanceMigrator::YamlColumnMigrator.new(source_environment, source_seed)
        yaml_migrator.migrate_yaml_columns
        puts "Time taken for yaml migration: #{Time.now - time_start}"
      end
    end

    unless ENV["SKIP_S3_ASSET_MIGRATION"]
      puts "Migrating s3 assets ...."
      time_start = Time.now
      source_org_id = ActiveRecord::Base.connection.exec_query("select id from #{source_cloned_db}.programs where parent_id IS NULL").rows.flatten.first
      s3_migrator_options[:source_org_id] = source_org_id
      s3_migrator_options[:target_common_bucket] = APP_CONFIG[:chronus_mentor_common_bucket]
      s3_migrator_options[:source_common_bucket] = YAML::load(ERB.new(File.read("#{Rails.root}/config/settings.yml")).result)[source_environment].symbolize_keys[:chronus_mentor_common_bucket]
      s3_asset_migrator = InstanceMigrator::S3AssetsMigrator.new(source_environment, source_seed, s3_asset_file_path, s3_migrator_options)
      s3_asset_migrator.migrate_assets
      puts "Time taken for s3 migration: #{Time.now - time_start}"
    end
  end

  desc "Backup temp tables after organization migration"
  # bundle exec rake instance_migration:backup_temp_tables BACKUP_DB="academywomen_backup_db"
  task :backup_temp_tables => :environment do
    backup_db = ENV["BACKUP_DB"]
    raise "BACKUP_DB must be passed as one of the arguments" unless backup_db.present?
    sql_commands = []
    sql_commands << "CREATE TABLE #{backup_db}.temp_model_table_map (model_name VARCHAR(191), table_name VARCHAR(191), target_max_id INT, source_max_id INT);"
    sql_commands << "CREATE TABLE #{backup_db}.temp_common_join_table (table_name VARCHAR(191), source_j_id INT, target_j_id INT);"
    temp_tables = ["temp_model_table_map", "temp_common_join_table"]
    temp_tables.each do |temp_table|
      sql_commands << "INSERT INTO #{backup_db}.#{temp_table} (SELECT * FROM #{temp_table});"
      sql_commands << "DROP TABLE IF EXISTS #{temp_table};"
    end
    sql_commands.each do |sql|
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  desc "Reindex elasticseach models after organization migration"
  # bundle exec rake instance_migration:reindex_elasticsearch SOURCE_ENVIRONMENT=<environment from which organization is migrated> SOURCE_SEED=<organization migration date ex:17_Aug_2017>
  # bundle exec rake instance_migration:reindex_elasticsearch SOURCE_ENVIRONMENT="academywomen" SOURCE_SEED="17_Aug_2017"
  task :reindex_elasticsearch => :environment do
    source_environment = ENV["SOURCE_ENVIRONMENT"]
    source_seed = ENV["SOURCE_SEED"]
    time_start = Time.now
    InstanceMigrator::ElasticsearchIndexer.new(source_environment, source_seed).reindex
    puts "Time taken for elasticseach migration: #{Time.now - time_start}"
  end

  # bundle exec rake instance_migration:reactivate_organization RAILS_ENV=<rails_env> DOMAIN=<domain> SUBDOMAIN=<subdomain> ACCOUNT_NAME=<account_name>
  task :reactivate_organization => :environment do
    Common::RakeModule::Utils.execute_task do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]

      organization.account_name = ENV['ACCOUNT_NAME'] if ENV['ACCOUNT_NAME'].present?
      organization.active = true
      organization.save!
    end
  end

  desc "Dump database into an SQL file"
  task :dump_clone_db => :environment do
    Common::RakeModule::Utils.execute_task do
      source_sql_db = ENV["SOURCE_CLONE_DB"]
      db_file_path = ENV["DB_FILE_PATH"]
      db_config = ActiveRecord::Base.configurations[Rails.env]
      host_or_socket = db_config.has_key?('host') ? "-h #{db_config['host']}" : "-S #{db_config['socket']}"
      sh "mysqldump #{host_or_socket} -u #{db_config['username']} #{'-p' if ENV['DATABASE_PWD'].present?}#{ENV['DATABASE_PWD']} --opt #{source_sql_db} | gzip -c > #{db_file_path}"
    end
  end

  desc "Load from SQL file to the database"
  task :load_clone_db => :environment do
    Common::RakeModule::Utils.execute_task do
      target_sql_db = ENV["TARGET_CLONE_DB"]
      db_file_path = ENV["DB_FILE_PATH"]
      db_config = ActiveRecord::Base.configurations[Rails.env]
      host_or_socket = db_config.has_key?('host') ? "-h #{db_config['host']}" : "-S #{db_config['socket']}"
      raise "Please specify DB_FILE_PATH." unless db_file_path
      command = ''
      command << "gunzip -c #{db_file_path} | " if db_file_path.end_with? '.gz'
      command << "mysql #{host_or_socket} -u #{db_config['username']} #{'-p' if ENV['DATABASE_PWD'].present?}#{ENV['DATABASE_PWD']} #{target_sql_db}"
      command << " < #{db_file_path}" unless db_file_path.end_with? '.gz'
      ActiveRecord::Base.connection.execute "DROP DATABASE IF EXISTS #{target_sql_db}"
      ActiveRecord::Base.connection.execute "CREATE DATABASE #{target_sql_db}"
      sh command
    end
  end

  desc "delete the entries created in target environment with the given source environment and source seed in case anything goes wrong"
  task :delete_entries_in_target_db => :environment do
    Common::RakeModule::Utils.execute_task do
      db_config = ActiveRecord::Base.configurations[Rails.env]
      source_environment = ENV["SOURCE_ENVIRONMENT"]
      source_seed = ENV["SOURCE_SEED"]
      raise "Please enter SOURCE_ENVIRONMENT and SOURCE_SEED" if source_environment.blank? || source_seed.blank?
      begin
        DateTime.strptime(source_seed, "%d_%b_%Y")
      rescue
        raise "Please enter SOURCE_SEED in format like 21_Apr_2017"
      end
      database = db_config['database']
      tables = ActiveRecord::Base.connection.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = '#{database}'").to_a.flatten
      (tables - ["schema_migrations", "temp_common_join_table", "temp_model_table_map"]).each do |table|
        ActiveRecord::Base.connection.execute("DELETE FROM #{table} WHERE source_audit_key LIKE '#{source_environment}_#{source_seed}_%'")
      end
    end
  end

  # bundle exec rake instance_migration:collect_members_of_non_migrated_programs RAILS_ENV=<rails_env> DOMAIN=<domain> SUBDOMAIN=<subdomain> ROOTS=<non_migrated_program_roots>
  desc "collect members who will become dormant after given programs are migrated"
  task :collect_members_of_non_migrated_programs => :environment do
    non_migrated_programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])
    csv_file_path = "tmp/members_of_non_migrated_programs.csv"
    CSV.open(File.join(Rails.root, csv_file_path), "w") do |csv|
      csv << ["Email", "Program Names"]
      migrated_programs = organization.programs.where.not(id: non_migrated_programs.collect(&:id))
      members = organization.members
      migrated_program_member_ids = members.includes(:users).references(:users).where("users.program_id IN (?)", migrated_programs.pluck(:id)).pluck(:id)
      members_to_be_dormant = members.includes(:users).references(:users).where("users.program_id IN (?)", non_migrated_programs.collect(&:id)).where.not(id: migrated_program_member_ids)
      program_names_hash = {}
      members_to_be_dormant.each do | member |
        program_ids = member.users.order(:program_id).pluck(:program_id)
        program_names_hash[program_ids] ||= organization.programs.where(id: program_ids).pluck(:name).join(", ")
        csv << [member.email, program_names_hash[program_ids]]
      end
    end
    Common::RakeModule::Utils.print_success_messages("Members are collected in #{csv_file_path}")
  end


 # bundle exec rake instance_migration:validate_polymorphic_associations FILE=<file_path>
  desc "Collect all missed has_one/has_many associations for the belongs_to polymorphic association"
  task :validate_polymorphic_associations => :environment do
    csv_file_path = ENV['FILE'] || 'tmp/missed_polymorphic_associations.csv'
    validator = InstanceMigrator::PolymorphicAssociationsValidator.new(csv_file_path)
    validator.validate_and_print
    message = if validator.missed_polymorphic_associations.present?
      "Missed has_one/has_many associations for the belongs_to polymorphic association are collected in the path : #{csv_file_path}. Please create the reverse associations."
    else
      "For all the belongs_to polymorphic association, has_one/has_many associations are present."
    end
    Common::RakeModule::Utils.print_success_messages(message)
  end

  # bundle exec rake instance_migration:validate_yaml_columns FILE=<file_path>
  desc "Collect newly introduced keys for the existing yaml columns"
  task :validate_yaml_columns => :environment do
    csv_file_path = ENV['FILE'] || 'tmp/yaml_column_validator.csv'
    validator = InstanceMigrator::YAMLColumnValidator.new(csv_file_path)
    validator.validate
    message = "Newly introduced yaml keys for the existing yaml columns are collected in the path : #{csv_file_path}. Please handle them in InstanceMigrator::YamlColumnMigrator."
    Common::RakeModule::Utils.print_success_messages(message)
  end

  # bundle exec rake instance_migration:collect_all_s3_attachments FILE=<file_path>
  desc "Collect all s3 attachments for the environment"
  task :collect_all_s3_attachments => :environment do
    csv_file_path = ENV['FILE'] || 'tmp/s3_assets_file.csv'
    collector = InstanceMigrator::S3AssetsCollector.new(csv_file_path)
    collector.collect_s3_assets
    Common::RakeModule::Utils.print_success_messages("S3 Attachments are collected !")
  end


  # bundle exec rake instance_migration:collect_rows_count FILE=<csv_file_path> SOURCE_CLONED_DB=<cloned_db_dump>
  desc "Collect the rows count for all the models in a csv."
  task :collect_rows_count => :environment do
    if (source_clone_db = ENV['SOURCE_CLONED_DB']).present?
      Common::RakeModule::Utils.establish_cloned_db_connection(source_clone_db)
    end
    connection = ActiveRecord::Base.connection
    current_db = connection.current_database
    tables = connection.tables
    tables.delete_if { |table_name| table_name.starts_with? "lhm" }
    tables_to_ignore = ["temp_common_join_table", "temp_model_table_map"]
    csv_file_path = ENV['FILE'] || File.join(Rails.root, "tmp/#{current_db}_row_counts.csv")
    CSV.open(csv_file_path, "w") do |csv|
      (tables - tables_to_ignore).each do |table_name|
        row_count = connection.exec_query("select count(*) from #{current_db}.#{table_name}").rows.flatten.first
        csv << [table_name, row_count]
      end
    end
  end

end