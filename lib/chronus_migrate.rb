module ChronusMigrate
  extend self

  #Custom migration which sets up a maintenance page if has_downtime: true
  def data_migration(options = {:has_downtime => true})
    self.set_maintenance_page unless (Rails.env.development? || Rails.env.test? || (options[:has_downtime] == false))
    yield
  end

  def ddl_migration(options = {:has_downtime => false})
    self.set_maintenance_page unless (Rails.env.development? || Rails.env.test? || (options[:has_downtime] == false))
    yield
    cleanup_old_tables if Rails.env.test?
  end

  def set_maintenance_page(deadline = nil, reason = nil)
    maintenance_page = "#{Rails.root.to_s}/public/system/maintenance.html"
    unless File.file?(maintenance_page)
      env = Rails.env
      maintenance = ERB.new(File.read("#{Rails.root.to_s}/script/maint.html.erb")).result(binding)
      maint_page = File.open(maintenance_page, "w")
      maint_page.write(maintenance)
      maint_page.close
    end
  end

  #If an Lhm migration is interrupted, it may leave behind the temporary tables and/or triggers used in the migration. If the migration is re-started, the unexpected presence of these tables will cause an error. This will cleanup these temporary tables and backup tables(old tables before the ddl migrations).
  def cleanup_old_tables
    Lhm.cleanup(:run)
  end

  #Execute mysql statements after the migration and indexing for column rename or changing column default
  def execute_mysql_statements_after_lhm_migration
    if File.file?(LhmConstants::LHM_MIGRATION_STATEMENTS)
      statements = File.read(LhmConstants::LHM_MIGRATION_STATEMENTS).split(",")
      begin
        statements.each do |statement|
          ActiveRecord::Base.connection.execute(statement)
        end
        FileUtils.rm(LhmConstants::LHM_MIGRATION_STATEMENTS)
      rescue => e
        abort "Error in executing delayed migration statements: #{e.message}. Contact Ops team"
      end
    end
  end
end