namespace :server_migration do

  module Defaults
    DOMAIN    = 'chronus.com'
    SUBDOMAIN = 'nationwidechildrens'
  end

  namespace :production do

    # Usage:
    # rake server_migration:production:make_nch_inactive --trace
    # 
    # WITH DOMAIN AND SUBDOMAIN FOR TESTING:
    # rake server_migration:production:make_nch_inactive domain='realizegoal.com' subdomain='nationwidechildrens' --trace
    desc "Make NCH organization inactive in Production database"
    task :make_nch_inactive => :environment do
      domain       = ENV['domain']    ||= Defaults::DOMAIN
      subdomain    = ENV['subdomain'] ||= Defaults::SUBDOMAIN
      organization = Program::Domain.get_organization(domain, subdomain)
      log_csv      = File.join(Rails.root.to_s, 'tmp', "production_migration_#{Time.now.to_i}.csv")
      csv          = write_benchmark_log_header(log_csv)

      bm = Benchmark.realtime do
        if organization.present? && organization.active?
          organization.active = false
          organization.save!
        end
      end
      log_benchmark(csv, organization.name, bm, 'ORG INACTIVE')
      csv.close
      p log_csv
    end

    # Usage:
    # rake server_migration:production:delete_nch_org --trace
    # 
    # WITH DOMAIN AND SUBDOMAIN FOR TESTING:
    # rake server_migration:production:delete_nch_org domain='realizegoal.com' subdomain='nationwidechildrens' --trace
    desc "Delete NCH organization from Production database"
    task :delete_nch_org => :environment do
      ENV['domain']    = Defaults::DOMAIN    if ENV['domain'].blank?
      ENV['subdomain'] = Defaults::SUBDOMAIN if ENV['subdomain'].blank?
      log_csv          = File.join(Rails.root.to_s, 'tmp', "production_migration_#{Time.now.to_i}.csv")
      csv              = write_benchmark_log_header(log_csv)
      bm               = Benchmark.realtime {Rake::Task['organization:destroy'].invoke}
      log_benchmark(csv, 'NCH', bm, 'ORG DELETE')
      csv.close
      p log_csv
    end

  end #namespace :production

  namespace :nch do

    # Usage:
    # rake server_migration:nch:make_other_orgs_inactive --trace
    # 
    # WITH DOMAIN AND SUBDOMAIN FOR TESTING:
    # rake server_migration:nch:make_other_orgs_inactive domain='realizegoal.com' subdomain='nationwidechildrens' --trace
    desc "Make All organizations except NCH inactive in NCH database"
    task :make_other_orgs_inactive => :environment do
      domain       = ENV['domain']    ||= Defaults::DOMAIN
      subdomain    = ENV['subdomain'] ||= Defaults::SUBDOMAIN
      nch_org      = Program::Domain.get_organization(domain, subdomain)
      log_csv      = File.join(Rails.root.to_s, 'tmp', "nch_migration_#{Time.now.to_i}.csv")
      csv          = write_benchmark_log_header(log_csv)
      if nch_org.present?
        Organization.where("id != :nch_org", nch_org: nch_org.id).each do |organization|
          bm = Benchmark.realtime do
            organization.active = false
            organization.save!
          end
          log_benchmark(csv, organization.name, bm, 'ORG INACTIVE')
        end
      else
        raise "NCH organization not present"
      end
      csv.close
      p log_csv
    end

    # Usage:
    # rake server_migration:nch:delete_other_orgs DELETE_COUNT=10 ORG_IDS=1,2,3 --trace >> log/server_migration_nch_delete_other_orgs.log 2>&1
    desc "Delete All organizations except NCH organization(and other active orgs like pingdom and walkthrunch) from NCH database"
    task :delete_other_orgs => :environment do
      log_csv      = File.join(Rails.root.to_s, 'tmp', "nch_migration_#{Time.now.to_i}.csv")
      csv          = write_benchmark_log_header(log_csv)
      delete_count = ENV['DELETE_COUNT'].to_i
      org_ids      = (ENV['ORG_IDS'].present? ? ENV['ORG_IDS'].split(',').collect(&:to_i) : [])
      org_names    = []
      exit         = false
      organizations= (org_ids.present? ? Organization.where(id: org_ids) : Organization.where(active: false).first(delete_count))
      trap('INT') do
        exit = trap_handler(exit, 'INT')
      end
      trap('TERM') do
        exit = trap_handler(exit, 'TERM')
      end
      organizations.each do |organization|
        p "Exiting on interrupt" and break if exit
        bm = Benchmark.realtime {delete_organization_data(organization)}
        log_benchmark(csv, organization.name, bm, 'ORG DELETE')
        org_names << organization.name
        log_memory("At the end of #{organization.name} deletion")
      end
      Airbrake.notify("Deleted #{org_names.join(', ')} from NCH server. Output CSV available here: #{log_csv}")
      csv.close
    end

  end #namespace :nch

  def log_benchmark(csv, organization_name, benchmark, event)
    csv << [organization_name, ENV['domain'], ENV['subdomain'], event, benchmark]
    csv.flush
  end

  def write_benchmark_log_header(csv_path)
    csv = CSV.open(csv_path, 'w')
    csv << ['Organization name', 'Domain', 'Subdomain', 'Event', 'Realtime(in seconds)']
    csv
  end

  def trap_handler(exit, interrupt_type)
    unless exit
      exit = true
      p 'Press Ctrl+c again to interrupt immediately'
      return exit
    else
      raise SignalException, interrupt_type
    end
  end

  def delete_organization_data(organization)
    unless organization.active?
      Rails.application.eager_load!
      p "Deleting #{organization.name}"
      model_deletion = TargetDeletion.new("Organization", organization.id)
      model_deletion.collect_data_to_be_deleted
      model_deletion.delete_db_data
      model_deletion.delete_s3_data
      model_deletion.print_errors
    end
  end

  def log_memory(text)
    puts "Process: #{Process.pid},#{[text, 'RAM USAGE: ' + `pmap #{Process.pid} | tail -1`[10,40].strip]}, Time: #{Time.now}\n"
  end

end #namespace :server_migration