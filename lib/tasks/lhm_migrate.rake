namespace :lhm do
  desc "Execute mysql statements after LHM migration"
  task execute_after_migrate_statements: :environment do
    ChronusMigrate.execute_mysql_statements_after_lhm_migration
  end

  desc "Cleanup leftover LHM tables/triggers"
  task cleanup_lhm_tables: :environment do
    ChronusMigrate.cleanup_old_tables
  end
end

#For development environment, run the delayed statements after db migration itself
if Rails.env.development? || Rails.env.test?
  Rake::Task["db:migrate"].enhance do
    Rake::Task["lhm:execute_after_migrate_statements"].invoke
    Rake::Task["lhm:cleanup_lhm_tables"].invoke
  end
  Rake::Task["db:rollback"].enhance do
    Rake::Task["lhm:execute_after_migrate_statements"].invoke
    Rake::Task["lhm:cleanup_lhm_tables"].invoke
  end
end