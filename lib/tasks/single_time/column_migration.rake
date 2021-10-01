#This rake will no longer work. Please don't use this again.

# USAGE: rake single_time:column_migration:add_column_source_audit_key
# USAGE: rake single_time:column_migration:add_column_source_audit_key TABLES='users,members'
# USAGE: rake single_time:column_migration:remove_column_source_audit_key
# USAGE: rake single_time:column_migration:remove_column_source_audit_key TABLES='users,members'
# USAGE: rake single_time:column_migration:drop_triggers_and_switch_tables
# USAGE: rake single_time:column_migration:drop_triggers_and_switch_tables TABLES='users,members'
# USAGE: rake single_time:column_migration:list_tables_without_column_source_audit_key
# USAGE: rake single_time:column_migration:cleanup_lhm_tables

namespace :single_time do
  namespace :column_migration do
    desc 'To add column source_audit_key to all tables'
    task :add_column_source_audit_key => :environment do
      options = {:table_names => ENV['TABLES'].try(:split, ",")}
      migrator = MigrationToAddColumnSourceAuditKey.new(options)
      migrator.add_column_migration
    end

    desc 'To rollback added column source_audit_key in all tables'
    task :remove_column_source_audit_key => :environment do
      options = {:table_names => ENV['TABLES'].try(:split, ",")}
      migrator = MigrationToAddColumnSourceAuditKey.new(options)
      migrator.remove_column_migration
    end

    desc 'To drop the triggers created by LHM gem and to swap original_table and lhm_table'
    task :drop_triggers_and_switch_tables => :environment do
      options = {:table_names => ENV['TABLES'].try(:split, ",")}
      migrator = MigrationToAddColumnSourceAuditKey.new(options)
      migrator.switch_tables
    end

    desc "To list tables which doesn't have column source_audit_key"
    task :list_tables_without_column_source_audit_key => :environment do
      migrator = MigrationToAddColumnSourceAuditKey.new
      migrator.list_tables_without_column_source_audit_key
    end

    desc 'To remove the temporary tables created by LHM gem during migration'
    task :cleanup_lhm_tables => :environment do
      Lhm.cleanup(true)
    end

  end
end