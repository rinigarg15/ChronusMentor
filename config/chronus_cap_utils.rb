require 'launchy'
require 'highline/import'
require 'airbrake/capistrano/tasks'
require 'new_relic/recipes'
require File.dirname(__FILE__) + '/cap/demo_task'
require File.dirname(__FILE__) + '/ops_cap_utils.rb'
require File.dirname(__FILE__) + '/../script/lib/aws_creds'
require File.dirname(__FILE__) + '/../script/lib/deployment_utils/recovery_utils'
require File.dirname(__FILE__) + '/../script/lib/deployment_utils/elb_utils'
require File.dirname(__FILE__) + '/../script/lib/deployment_utils/app_server_utils'
require File.dirname(__FILE__) + '/../script/lib/deployment_utils/aws_utils_v2'
require File.dirname(__FILE__) + '/../script/lib/deployment_utils/slack_utils'
require File.dirname(__FILE__) + '/../script/lib/single_touch_deployment/deployment_helper'
require File.dirname(__FILE__) + "/../script/lib/single_touch_deployment/service_maintenance"
require_relative  '../script/ops/user_mgmt_config.rb'
require 'ipaddress'
require 'aws-sdk-v1'
require 'fileutils'
include FileUtils
require 'tmpdir'
require 'zlib'
require 'archive/tar/minitar'
require 'colorize'
require 'aws-sdk'
include Archive::Tar

DEPLOY_YML = "config/deploy.yml"

module PagerDutyMaintenance
  SERVICES_MAPPER = {
    "Pingdom alerts" => "PDLLEN3",
    "newrelic-alerts" => "P7RCWZL",
    "SystemMonitor" => "PLCQ176",
    "monit-alerts" => "PDZMRXV"
  }
end

module MobileDeploy
  RELEASE_BRANCH_MAPPER = {
    "staging" => "staging_release",
    "standby" => "standby_release",
    "production" => "master",
    "productioneu" => "master",
    "demo" => "master",
    "generalelectric" => "master",
    "veteransadmin" => "master",
    "nch" => "master"
  }
end

Capistrano::Configuration.instance.load do

  def clear_all_roles
    roles.keys.each do |x|
      roles.delete(x)
    end
  end

  def current_deploy_action
    current_task.namespace.logger.instance_variable_get('@options')[:actions].last
  end

  def cold_deploy?
    current_deploy_action == "deploy:cold"
  end

  def chef_deploy?
    current_deploy_action == "chronus:chef:deploy"
  end

  def sftpserver_deploy?
    current_deploy_action == "chronus:sftpserver:deploy"
  end

  def set_hostfilter(hosts)
    ENV["HOSTFILTER"] = hosts
  end

  def set_primary_roles_cold_deploy
    ips_list = ""
    primary_ips, secondary_ips, web_ips, collapsed_ips = ENV["PRIMARY_APP_SERVER"], ENV["SECONDARY_APP_SERVER"], ENV["WEB_SERVER"], ENV["COLLAPSED_SERVER"]

    if primary_ips || secondary_ips || web_ips
      ips_list = set_app_web_server_roles_cold_deploy(primary_ips, secondary_ips, web_ips)
    elsif collapsed_ips
      ips_list += collapsed_ips
      collapsed_ips = collapsed_ips.split(",")
      role :web, *collapsed_ips
      role :app, *collapsed_ips
      role :db,  collapsed_ips.first, :primary => true
    else
      abort "Specify Server IP eg: cap opstesting deploy:cold COLLAPSED_SERVER=52.23.43.216"
    end
    set_hostfilter(ips_list)
  end

  def set_app_web_server_roles_cold_deploy(primary_ips, secondary_ips, web_ips)
    primary_ips_list, secondary_ips_list, web_ips_list = [], [], []
    primary_ips_list = primary_ips.split(",") if primary_ips
    secondary_ips_list = secondary_ips.split(",") if secondary_ips
    web_ips_list = web_ips.split(",") if web_ips

    if primary_ips_list.any?
      role :db, primary_ips_list.first, :primary => true
    end

    if primary_ips_list.any? || secondary_ips_list.any?
      role :app, *(primary_ips_list + secondary_ips_list)
    end

    if web_ips_list.any?
      role :web, *web_ips_list
    end

    (primary_ips_list + secondary_ips_list + web_ips_list).join(",")
  end

  def set_primary_roles(rails_env)
    #Getting IPs dynamically from ELB of an environment if present
    if elb_ips = get_ips_from_elb(rails_env)
      web_ips = elb_ips
      if @deploy_conf[rails_env]["type"] == "collapsed"
        app_ips = elb_ips
        primary_db_ip = elb_ips.first
      end
    end

    if @deploy_conf[rails_env]["type"] != "collapsed"
      primary_db_ip, app_ips = get_app_and_primary_db_ips
    end

    app_ips = @deploy_conf[rails_env]["app"] || app_ips
    web_ips = @deploy_conf[rails_env]["web"] || web_ips
    primary_db_ip = @deploy_conf[rails_env]["primary_db"] || primary_db_ip

    role :web, *web_ips
    role :app, *app_ips
    role :db,  primary_db_ip , :primary => true

    if @deploy_conf[rails_env]["backup"]
      role :app_backup, *@deploy_conf[rails_env]["backup"]["app"], :no_release => true
      role :web_backup, *@deploy_conf[rails_env]["backup"]["web"], :no_release => true
    end
  end

  def get_app_and_primary_db_ips
    primary_ips, secondary_ips = get_app_server_ips
    if primary_ips.size != 1
      raise "No primary app server is running" if primary_ips.empty?
      raise "Multiple primary app servers are running"
    end
    app_ips = primary_ips + secondary_ips
    primary_db_ip = primary_ips.first
    [primary_db_ip, app_ips]
  end

  def set_primary_roles_for_sftpserver
    role :sftpserver, @deploy_conf[rails_env]["sftpserver"]
  end

  def set_primary_roles_for_chef(rails_env)
    #Getting IPs dynamically from ELB of an environment if present
    if elb_ips = get_ips_from_elb(rails_env)
      web_ips = elb_ips
      app_ips = elb_ips if @deploy_conf[rails_env]["type"] == "collapsed"
    end

    if @deploy_conf[rails_env]["type"] != "collapsed"
      primary_db_ip, app_ips = get_app_and_primary_db_ips
    end

    web_ips = @deploy_conf[rails_env]["web"] || web_ips
    app_ips = @deploy_conf[rails_env]["app"] || app_ips

    role :web, *web_ips
    role :app, *app_ips
    role :sftp, *@deploy_conf[rails_env]["sftpserver"]
    if @deploy_conf[rails_env]["backup"]
      role :web, *@deploy_conf[rails_env]["backup"]["web"]
      role :app, *@deploy_conf[rails_env]["backup"]["app"]
      role :sftp, *@deploy_conf[rails_env]["backup"]["sftpserver"]
    end
  end

  def get_app_server_ips
    options = {region: region, access_key_id: dev_creds["S3_KEY"], secret_access_key: dev_creds["S3_SECRET"]}
    app_server_util = DeploymentUtils::AppServerUtils::Manager.new(rails_env, options)
    app_server_util.get_app_ips_based_on_tags
  end

  def get_ips_from_elb(rails_env)
    setup_app_creds
    options = {region: region, :access_key_id => dev_creds["S3_KEY"], :secret_access_key => dev_creds["S3_SECRET"]}
    elb_util = DeploymentUtils::ELBUtils::Manager.new(rails_env, options)
    elb_util.get_elb_target_ips
  end 

  def define_env(name)
    before  name, "deploy:set_deploy_env_for_roles"
    desc "Set params for #{name}"
    task name.to_sym do
      clear_all_roles
      set :current_deploy_mode, name
      set :rails_env, name
      set :rack_env, name
      set :rake, "bundle exec rake"
      set :region, @deploy_conf[name]["region"]
      set :branch, *@deploy_conf[name]["branch"]
      if chronus_chef_deploy
        set_primary_roles_for_chef(rails_env)
      elsif chronus_sftpserver_deploy
        set_primary_roles_for_sftpserver
      else
        set_config_variables
        chronus_cold_deploy ? set_primary_roles_cold_deploy : set_primary_roles(rails_env)
      end
      setup_role_names
    end

    after name, "chronus:setup_ssh_options"
  end

  def deploy_help
    <<-eos

Environment variables available (All variables default to false)
FORCE_FULL_DEPLOYMENT         - Will take the full deployment route if there is no migrations

DISABLE_MATCH_INDEXING        - Skip scheduling matching indexing task. Note: Will run as part of cron (6 hours)
DISABLE_DELAYED_JOB_RESTART   - Skip all dj related tasks. Note: Will be started by monit later
DISABLE_CLEAR_CACHE           - Skip memcache clear cache.

PERFORM_MATCH_INDEXING_NOW    - Run matching indexing immediately instead of running it in DJ.
    eos
  end

  # Sets configuration variables based on ENV
  def set_config_variables
    set :force_full_deployment, (ENV['FORCE_FULL_DEPLOYMENT'] == 'true')

    set :skip_match_indexing, (ENV['DISABLE_MATCH_INDEXING'] == 'true')
    set :full_es_reindex, (ENV['FULL_ES_REINDEX'] == 'true')

    set :skip_es_reindex, (ENV['DISABLE_ES_REINDEX'] == 'true')
    set :skip_migrations, false
    set :skip_delayed_job_restart, (ENV['DISABLE_DELAYED_JOB_RESTART'] == 'true')
    set :skip_clear_cache, (ENV['DISABLE_CLEAR_CACHE'] == 'true')
    set :skip_recovery_setup, (ENV['SKIP_RECOVERY_SETUP'] == 'true') # ENV['SKIP_RECOVERY_SETUP'] is a string if given irrespective of value it represents

    set :perform_match_indexing_now , (ENV['PERFORM_MATCH_INDEXING_NOW'] == 'true')
    set :delayed_migrator_statements_present, false
    set :cred_path, current_path
  end

  def make_admin_role_for(role)
    newrole = "#{role.to_s}_admin".to_sym
    roles[role].each do |srv_def|
      options = srv_def.options.dup
      options[:user] = "admin"
      options[:port] = srv_def.port
      options[:no_release] = true
      role newrole, srv_def.host, options
    end
  end

  def setup_role_names
    # This is required for ec2onrails gem to work. The method body is a
    # copied from the ec2onrails gem.

    # make an "admin" role for each role, and create arrays containing
    # the names of admin roles and non-admin roles for convenience
    set :all_admin_role_names, []
    set :all_non_admin_role_names, []
    roles.keys.clone.each do |name|
      make_admin_role_for(name)
      all_non_admin_role_names << name
      all_admin_role_names << "#{name.to_s}_admin".to_sym
    end
  end

  # Read the deploy.yml file and setup the "environment" tasks.
  def initialize_config

    if ENV['DISASTER_RECOVERY']
      @deploy_conf = YAML.load_file("config/deploy_dr.yml")
    else
      @deploy_conf = YAML.load_file(DEPLOY_YML)
    end

    @default_env = nil
    @environments = []

    @deploy_conf.each do |k, v|
      @environments << k
      @default_env = k if !@deploy_conf[k]["default"].nil?
      # define the "environment" task for the current env.
      define_env(k)
    end

    @default_env ||= "staging"
    set :maintenance_page, "#{shared_path}/system/maintenance.html"

  end

  def execute_for_env(env, task)
    find_and_execute_task(env)
    find_and_execute_task(task)
  end

  # Move the string as a file in a previleged directory
  def install_str_as_file(str, file_path, owner = "root")

    fname = file_path.split("/").last

    put str, "/tmp/#{fname}"
    sudo "rm -f #{file_path}"
    sudo "mv /tmp/#{fname} #{file_path}"
    sudo "chown #{owner}:#{owner} #{file_path}"
    sudo "chmod 0400 #{file_path}"
  end

  def get_required_ssh_keypaths
    app_ssh_dir = "#{Dir.home}/#{CmIamConfig::APP_SSH_KEY_LOCAL_FOLDER_NAME}"
    app_ssh_key_suffix = "#{CmIamConfig::APP_SSH_KEY_NAME_SUFFIX}"

    sshkey_path = "#{app_ssh_dir}/#{rails_env}-#{app_ssh_key_suffix}"
    abort("#{sshkey_path} not found!") unless File.exists?(sshkey_path)
    return ["#{sshkey_path}"]
  end

  def migrations_or_indexing_not_required
    skip_migrations && skip_es_reindex
  end

  def maintenance_page_required
    (delayed_migrator_statements_present || !skip_es_reindex)
  end

  def create_list(type,options)
    options.split(',').map { |option| "#{type}[#{option}]" }.join(',')
  end

  def is_backup_instance(instance_ip)
    return false unless @deploy_conf[rails_env]["backup"]
    @deploy_conf[rails_env]["backup"].values.flatten.uniq.include?(instance_ip)
  end

  def run_chef_client(server,chef_recipes,chef_roles)
    instance_ip = server.host
    AWSUtilsV2.initialize_aws_v2(dev_creds["S3_KEY"], dev_creds["S3_SECRET"], region)
    ec2_instance = AWSUtilsV2.get_ec2_instance(instance_ip)
    instance_id = ec2_instance.instance_id
    stopped_instance = (ec2_instance.state.name == "stopped")
    AWSUtilsV2.start_instance(instance_ip) if stopped_instance && is_backup_instance(instance_ip)
    counter = 0
    begin
      if chef_recipes
        sudo "chef-client -o #{create_list('recipe',chef_recipes)}", :hosts => server
      elsif chef_roles
        sudo "chef-client -o #{create_list('role',chef_roles)}",  :hosts => server
      else
        sudo "chef-client",  :hosts => server
      end
    rescue Net::SSH::Disconnect, Errno::ECONNREFUSED, Errno::ECONNRESET, Capistrano::ConnectionError => e
      teardown_connections_to(sessions.keys)
      counter += 1
      sleep 2
      retry if counter < 10
    end
    AWSUtilsV2.stop_instance(instance_ip) if stopped_instance && is_backup_instance(instance_ip)
  end

  def check_dir_presence(ip, dir)
    counter = 0
    tmp_present = nil
    begin
      tmp_present = capture "ls #{dir}" , :hosts => ip
    rescue Capistrano::CommandError => e
      tmp_present = false
    rescue Net::SSH::Disconnect, Errno::ECONNREFUSED, Errno::ECONNRESET, Capistrano::ConnectionError => e
      puts "Retrying to reach webserver"
      counter += 1
      sleep 1
      retry if counter < 10 && tmp_present.nil?
      tmp_present = false
    end
  end

  def clear_dir(ip, dir)
    counter = 0
    begin
      capture "rm -rf #{dir}/* ", :hosts => ip
    rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Capistrano::ConnectionError => e
      teardown_connections_to(sessions.keys) # To reset the connection https://groups.google.com/forum/#!topic/capistrano/qRny53t8iig
      counter += 1
      retry if counter < 10
      cleared = false
    end
    cleared = true
  end

  def is_collapsed_setup?
    deploy_conf = YAML.load_file(DEPLOY_YML)
    @deploy_conf[rails_env]["type"] == "collapsed"
  end

  def is_backup_present?(type)
    @deploy_conf[rails_env]["backup"] && @deploy_conf[rails_env]["backup"][type]
  end

  def perform_recovery_setup_util
    server_type_from_role = current_task.options[:roles].to_s.split("_").first
    actual_server_type = (is_collapsed_setup? ? "collapsed" : server_type_from_role)
    if is_backup_present?(server_type_from_role)
      begin
        puts "Performing ebs volume backup for recovery for #{actual_server_type} server in #{rails_env}"
        primary_server_ip = find_servers_for_task(current_task).collect(&:host).first
        backup_ips = @deploy_conf[rails_env]["backup"][server_type_from_role]

        options = {:access_key_id => dev_creds["S3_KEY"], :secret_access_key => dev_creds["S3_SECRET"], region: region, primary_ip: primary_server_ip, backup_ips: backup_ips}
        recovery_util = DeploymentUtils::RecoveryUtils::Manager.new(rails_env, actual_server_type, options)
        recovery_util.perform_recovery_steps

      rescue => exception
        raise "Error: #{exception.message} \nRecovery setup failed, please rerun deploy:perform_recovery_setup task again"
      end
    end
  end

  def perform_recover_common(common_options = {})
    server_type_from_role = current_task.options[:roles].to_s.split("_").first
    actual_server_type = (is_collapsed_setup? ? "collapsed" : server_type_from_role)
    actual_server_type = (common_options[:primary] ? "primary_app" : "seconday_app") if actual_server_type == "app"
    servers = find_servers_for_task(current_task)
    abort "Backup IPs not present" if servers.empty?
    options = {region: region, :access_key_id => dev_creds["S3_KEY"], :secret_access_key => dev_creds["S3_SECRET"]}
    recovery_util = DeploymentUtils::RecoveryUtils::Manager.new(rails_env, actual_server_type, options)

    servers.each do |server|
      recovery_util.recover_backup_instance(server.host)
      if agree("Proceed to clear Rails tmp? y/n")
        raise "tmp is not present" unless check_dir_presence(server.host, "#{current_path}/tmp")
        puts "Couldnt remove rails tmp directory. Please remove it manually" unless clear_dir(server.host, "#{current_path}/tmp")
      end
      configure_app_creds
      if agree("Run chef-client  (may take 1.5 mins)? y/n")
        chef_roles, chef_recipes = ENV["CHEF_ROLES"], ENV["CHEF_RECIPES"]
        run_chef_client(server, chef_recipes, chef_roles)
      end
    end
    puts "Starting monit"
    start_and_monitor_monit if agree("Start Monit  (may take 2 mins)? y/n")
    if agree("Start Cron ? y/n")
      start_cron_service
    end

    #update Tags
    app_server_util = DeploymentUtils::AppServerUtils::Manager.new(rails_env, options)
    app_server_util.update_server_role_tag(servers.collect(&:host), role_name: actual_server_type)

    #If you want to assign current running server's IP to this backup server
    servers.each do |server|
      if agree("Do you want to assign another IP(switch IP) to this server?(you will be asked IP in the next step) y/n")
        ip2 = ask("Enter the ip to assign to this server- ")
        recovery_util.switch_or_attach_ips(server.host, ip2)
      end
    end
    #NOTE: Don't add any task after switch IPs. It won't work
    puts "Recovery Done! Please stop the old servers with failure manually and remove them from ELB if applicable!"
  end

  def setup_app_creds
    if ENV['AWS_DEPLOY_USER'].nil? || ENV['AWS_DEPLOY_USER'].empty?
      deploy_user = "dev_#{rails_env}"
    else
      deploy_user = ENV['AWS_DEPLOY_USER']
    end

    cred_mgr = AWSCredential::Manager.new(deploy_user)

    if ENV['AWS_APP_USER'].nil? || ENV['AWS_APP_USER'].empty?
      app_user = "app_#{rails_env}"
    else
      app_user = ENV['AWS_APP_USER']
    end

    # Fetch the credentials of app user. Note that only users with deployment privelege can fetch the app user creds
    set :app_creds, cred_mgr.list_env_vars(app_user)

    #Fetch the credentials of dev user.
    set :dev_creds, cred_mgr.list_dev_keys

    #Set newrelic license key required for deployment notification
    set :newrelic_license_key, app_creds["NEWRELIC_LICENSE_KEY"]
  end

  def configure_app_creds
    abort("App credentials are not computed") if app_creds.empty?
    # Update the aws credentials of app user
    unless ENV['DISABLE_AWS_APP_USER_CREDS_UPDATE']

      app_cred_str = ""
      app_creds.keys.sort.each do |key|
        app_cred_str << "#{key}='#{app_creds[key]}'\n"
      end

      install_str_as_file app_cred_str, "#{cred_path}/config/.env", "app"
    end
  end

  def start_and_monitor_monit
    # Sleep of 130 secs is needed because monit has been configured to accept requests after 120 secs
    sudo "service monit restart; sleep 130"
    sudo "monit monitor all"
  end

  def start_cron_service
    sudo "service cron start; true"
  end

  def stop_cron_service
    sudo "service cron stop; true"
  end

  def run_interactively(command=nil)
    server ||= find_servers_for_task(current_task).first
    user = server.user || fetch(:user)
    ssh_command = %Q{ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i #{ssh_options[:keys].first} #{user}@#{server.host}}
    ssh_command += %Q{ -t 'cd #{current_path} && #{command}'} if command
    exec ssh_command
  end

  # Call initialize_config to have the env tasks setup.
  initialize_config

  namespace :rails do
    desc "Remote rails console"
    task :console, :roles => :db do
      run_interactively "bundle exec rails console #{rails_env}"
    end

    desc "Remote dbconsole"
    task :dbconsole, :roles => :db do
      run_interactively "bundle exec rails dbconsole #{rails_env}"
    end
  end

  namespace :ssh do
    desc "SSH into primary app server"
    task :app, :roles => :db_admin do
      run_interactively
    end

    desc "SSH into the first web server"
    task :web, :roles => :web_admin do
      run_interactively
    end
  end

  namespace :chronus do

    namespace :chef do
      before "chronus:chef:deploy", "deploy:slack:notify_deploy_start"
      after "chronus:chef:deploy", "deploy:slack:notify_deploy_finish"
      task :deploy, :roles => [:app_admin, :web_admin, :sftp_admin] do
        on_rollback { deploy.slack.notify_deploy_failed }
        deploy_conf = YAML.load_file(DEPLOY_YML)
        ENV["PAGERDUTY_API_KEY"] = app_creds["PAGERDUTY_API_KEY"]
        maintenance_id_arr = deploy_conf[rails_env]["backup"] ? ServiceMaintenance.new.pagerduty_maintenance(PagerDutyMaintenance::SERVICES_MAPPER.select{|key| key.match(/SystemMonitor/)}) : []
        find_servers_for_task(current_task).each do |current_server|
          chef_roles,chef_recipes = ENV["CHEF_ROLES"],ENV["CHEF_RECIPES"]
          run_chef_client(current_server,chef_recipes,chef_roles)
        end
        maintenance_id_arr.each { |id| ServiceMaintenance.new.stop_maintenance(id) }
      end
    end

    namespace :instance_migration do
      task :get_source_clone_db, :roles => [:db] do
        run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} instance_migration:dump_clone_db SOURCE_CLONE_DB='#{ENV['SOURCE_CLONE_DB']}' DB_FILE_PATH='/tmp/cloned_db.sql.gz'"
        download("/tmp/cloned_db.sql.gz", "/tmp/cloned_db.sql.gz", via: :scp)
        download("#{ENV['S3_ASSET_FILE_PATH']}", "/tmp/s3_assets_file.csv", via: :scp)
      end

      task :put_target_clone_db, :roles => [:db] do
        upload("/tmp/cloned_db.sql.gz", "/tmp/cloned_db.sql.gz", via: :scp)
        upload("/tmp/s3_assets_file.csv", "/tmp/s3_assets_file.csv", via: :scp)
        run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} instance_migration:load_clone_db TARGET_CLONE_DB='#{ENV['TARGET_CLONE_DB']}' DB_FILE_PATH='/tmp/cloned_db.sql.gz'"
      end
    end

    namespace :sftpserver do
      before "chronus:sftpserver:deploy", "chronus:sftpserver:setup_deploy_user"

      desc "set the deploy user to root."
      task :setup_deploy_user do
        set :user, "admin"
      end

      desc 'Deploys the code needed for feed uploader into sftpserver nodes'
      task :deploy, :roles => :sftpserver do
        rails_root = "#{File.dirname(File.dirname(__FILE__))}"
        begin
          filename = "feed_uploader_files.tar"
          local_file = "#{Dir.tmpdir}/#{filename}"
          remote_file = "/tmp/#{filename}"
          tar = File.open(local_file, 'wb')
          FileUtils.cd("#{rails_root}/feed_uploader") do
            # Do not modify directories and their permissions if they already exist. For e.g. / and /root are system folders
            # created as base ubuntu in chef with specific permissions. Including them in tar package below will cause issues
            # if permissions created by chef are not in sync.
            file_list = Find.find(".").select { |entry| !Dir.exist?(entry) }
            File.open(local_file, 'wb') { |tar| Minitar.pack(file_list, tar) }
          end
          put File.read(local_file), remote_file
          sudo "tar xvf #{remote_file} -o -C /"
          sudo "ruby /usr/local/chronus/lib/copy_to_feed_cron.rb #{rails_env}"
          sudo "service cron restart"
        ensure
          rm_rf local_file
          run "rm -f #{remote_file}"
        end
      end
    end

    namespace :cron do
      desc "Start the cron daemon"
      task :start, roles: [:app_admin, :web_admin] do
        start_cron_service
      end

      desc "Stop the cron daemon"
      task :stop, roles: [:app_admin, :web_admin] do
        stop_cron_service
      end
    end

    namespace :cron_tasks do
      desc "Schedules the cron tasks in DJ Queue"
      task :schedule, roles: :db_admin do
        run "cd #{current_path} && sudo #{rake} RAILS_ENV=#{rails_env} cron_tasks:schedule"
      end
    end

    namespace :delayed_job do
      desc "Start and monitor the delayed job worker daemon"
      task :start, roles: :app_admin do
        chronus.delayed_job.start_only
        chronus.delayed_job.start_monit
      end

      task :start_monit, roles: :app_admin do
        sudo "monit -g delayed_job monitor all"
      end

      desc "Stop and unmonitor the delayed job worker daemon"
      task :stop, roles: :app_admin do
        sudo "monit -g delayed_job unmonitor all"
        run "/usr/local/chronus/bin/delayed_job_stop"
      end

      desc "Start the delayed job worker daemon"
      task :start_only, roles: :app_admin do
        run "/usr/local/chronus/bin/delayed_job_start"
      end
    end

    namespace :memcached do
      desc "Start the memcached"
      task :start, :roles => :web_admin do
        # Need to do setsid of memcached
        # See issue described about memcached startup problems at http://tickets.opscode.com/browse/COOK-720
        sudo "setsid /etc/init.d/memcached start"
        sudo "monit -g memcache monitor all"
      end
      desc "Stop the memcached"
      task :stop, :roles => :web_admin do
        sudo "monit -g memcache unmonitor all"
        sudo "/etc/init.d/memcached stop"
      end
      desc "Restart the memcached"
      task :restart, :roles => :web_admin do
        sudo "monit -g memcache unmonitor all"
        sudo "setsid /etc/init.d/memcached restart"
        sudo "monit -g memcache monitor all"
      end
    end

    # --- Elasticsearch task ---
    namespace :es_reindex do
      desc "Start elasticsearch reindexing"
      task :reindex, :roles => :db do
        puts "Elasticsearch reindexing during deployment"
        if full_es_reindex
          run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} es_indexes:reindexing FORCE_REINDEX=true"
        elsif es_indexes_to_reindex and es_indexes_to_reindex.size != 0
          indexes_string = es_indexes_to_reindex.join(",")
          run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} es_indexes:reindexing MODELS=#{indexes_string} FORCE_REINDEX=true"
        end
      end

      task :flipping_es_indexes, :roles => :db do
        puts "Elasticsearch flipping of indexes during deployment"
        if full_es_reindex
          run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} es_indexes:flipping_index"
        elsif es_indexes_to_reindex and es_indexes_to_reindex.size != 0
          indexes_string = es_indexes_to_reindex.join(",")
          run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} es_indexes:flipping_index MODELS=#{indexes_string}"
        end
      end

      desc "Reindexing new indexes"
      task :reindex_new, :roles => :db do
        puts "Elasticsearch Reindexing for new indexes"
        indexes_string = new_es_indexes_to_reindex.join(",")
        run "cd #{current_path} && #{rake} RAILS_ENV=#{rails_env} es_indexes:full_indexing MODELS=#{indexes_string} FORCE_REINDEX=true"
      end
    end

    # ---- Matching tasks ----
    namespace :matching do
      desc "Reindex matching data"
      task :index, :roles => :db do
        if perform_match_indexing_now
          chronus.matching.index_now
        else
          run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} matching:full_index_and_refresh_later"
        end
      end
      task :index_now, :roles => :db do
        run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} matching:full_index_and_refresh"
      end
    end

    # ---- Clearing File Cache ----
    namespace :file_cache do
      desc "Clear cache files"
      task :clear, :roles => :web do
        run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} tmp:cache:clear"
      end
    end

    namespace :monit do
      desc "Starts the monit daemon and enables monitoring"
      task :start_and_monitor, :roles => [:app_admin, :web_admin] do
        start_and_monitor_monit
      end

      desc "Stops the monit daemon"
      task :stop, :roles => [:app_admin, :web_admin] do
        sudo "service monit stop; true"
      end
    end

    desc "Prepares the instance for cold deploy"
    task :setup, :roles => [:app_admin, :web_admin] do
      chronus.cron.stop
    end

    desc "Updates the app credentials with the latest from credential store. Meant to be called after rotating credentials"
    task :update_app_creds, :roles => [:app_admin, :web_admin] do
      setup_app_creds
      configure_app_creds
    end

    desc "Setting up the credential path"
    task :setup_cred_path do
      set :cred_path, release_path
    end

    desc "Configure ssh options"
    task :setup_ssh_options do
      ssh_options[:keys] = get_required_ssh_keypaths
    end

    desc "tail production log files"
    task :tail_logs, :roles => :web do
      file = ENV["LOG_FILE"] || "#{shared_path}/log/#{rails_env}.log"
      trap("INT") { puts 'Interupted'; exit 0; }
      run "tail -f #{file}" do |channel, stream, data|
        puts "#{channel[:host]}: #{data}"
        break if stream == :err
      end
    end

    desc "Pulls latest locales from phraseapp content_develop project to the production project and also uploades them to s3"
    task :backup_locales_from_phrase_to_production_project_and_s3, :roles => :db do
      while !system("mkdir /tmp/phraseapp_lock") #Allow to hit Phraseapp Api one at a time
        puts "Waiting for some other environment to complete Phraseapp sycn!"
        sleep 10
      end
      begin
        run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} globalization:bakup_latest_translations_for_deployment_and_sync_with_prod"
      ensure
        #Releasing the lock!
        system("rm -r /tmp/phraseapp_lock")
      end
    end

    desc "Pulls latest locales from s3 bucket to the releases"
    task :copy_locales_from_s3, :roles => [:app, :web] do
      run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} globalization:pull_translations_from_s3_bucket TARGET_PATH='#{release_path}/config/locales/'"
    end

    desc "Recreate the pseudolocalization YAML file if staging"
    task :pseudolocalize, :roles => [:app, :web] do
      if rails_env == "staging"
        run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} db:pseudolocalize"
      end
    end

    namespace :digest do

      before "chronus:digest:set_env", "chronus:digest:compute"

      desc "calculate the digest of databases and ES changes"
      task :compute, :roles => [:app, :web] do
        run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} digest_calculator:overall_digest"
        run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} digest_calculator:es_indexes_digest"
      end

      desc "Calculate digest of ES index"
      task :es_index, :roles => :db do
        next if chronus_cold_deploy
        unless full_es_reindex
          current_es_indexes_digest_path = "#{current_path}/es_indexes_digest.yml"
          release_es_indexes_digest_path = "#{release_path}/es_indexes_digest.yml"
          current_es_indexes_digest = YAML.load capture("if [ -f #{current_es_indexes_digest_path} ]; then  cat #{current_es_indexes_digest_path}; fi")
          new_es_indexes_digest = YAML.load capture("if [ -f #{release_es_indexes_digest_path} ]; then  cat #{release_es_indexes_digest_path}; fi")
          #Get indexes which needs to be reindexed where the version number is changed or if its a new index
          if (current_es_indexes_digest && new_es_indexes_digest)
            new_es_indexes_added = new_es_indexes_digest.keys - current_es_indexes_digest.keys 
            indexes_to_reindex = new_es_indexes_digest.keys.select{|k| current_es_indexes_digest[k] != new_es_indexes_digest[k]}
          else
            new_es_indexes_added, indexes_to_reindex = [], [] 
          end

          set :es_indexes_to_reindex, indexes_to_reindex
          set :new_es_indexes_to_reindex, new_es_indexes_added
        end
        set :skip_es_reindex, (skip_es_reindex || (!full_es_reindex && !(indexes_to_reindex && indexes_to_reindex.any?)))
      end 

      desc "setup environment variables based on digests calculated"
      task :set_env, :roles => [:app, :web] do
        next if chronus_cold_deploy
        current_digest_path = "#{current_path}/data_digest.yml"
        release_digest_path = "#{release_path}/data_digest.yml"
        current_data_digest = YAML.load capture("if [ -f #{current_digest_path} ]; then  cat #{current_digest_path}; fi")
        new_data_digest = YAML.load capture("if [ -f #{release_digest_path} ]; then  cat #{release_digest_path}; fi")

        es_config_unchanged = (current_data_digest && new_data_digest["ESINDEX"] && current_data_digest["ESINDEX"]  == new_data_digest["ESINDEX"])

        # Do full ES reindexing if ENV is set or if digest is different for config/elasticsearch_settings.yml
        set :full_es_reindex, (full_es_reindex || !es_config_unchanged || force_full_deployment)

        # Don't compare digest values if force full deployment is set
        next if force_full_deployment

        # Skip migrations if ENV is set or if digest for db/migrate remains same
        set :skip_migrations, (skip_migrations || (current_data_digest && new_data_digest["MYSQL"] && current_data_digest["MYSQL"]   == new_data_digest["MYSQL"]))
      end

    end

    namespace :mobile do
      ## TODO: This should be removed, when we start using the proper www/ folder
      ## TODO: Also this should be cleaned up, only appropriate files should be exposed.
      desc "Moves mobile related files to public folder"
      task :checkout, roles: :web do
        ## TODO This should be removed, when we release mobile in production.
        if MobileDeploy::RELEASE_BRANCH_MAPPER.keys.include?(rails_env)
          ## The REPLACE_MOBILE should **not be used** in full deploy eg. cap staging deploy
          project_dir = ENV["REPLACE_MOBILE"] ? current_path : release_path
          run "cd #{project_dir} && git clone -q -b #{MobileDeploy::RELEASE_BRANCH_MAPPER[rails_env]} git@github.com:ChronusCorp/ChronusMobile.git --depth 1"
          run "cd #{project_dir}/ChronusMobile"
          run "cd #{project_dir} && rm -rf public/mobile"
          run "cd #{project_dir} && cp -r ChronusMobile/platforms/ios/www public/mobile"
          run "cd #{project_dir} && cp -r ChronusMobile/platforms/android/assets/www public/mobile/android"
          run "cd #{project_dir} && rm -rf ChronusMobile"
        end
      end

      desc "Moves cordova js files to s3"
      task :move_cordova_files_to_s3, roles: :web do
        run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} mobile:move_cordovajs_s3"
      end
    end

    desc "Check if any delayed migration statements are to be run after indexing, just before the switch to the new codebase"
    task :check_delayed_custom_migrator, :roles => [:db] do
      begin
        run "test -f #{File.join(release_path, "tmp", "lhm_migration_statements")}"
        set :delayed_migrator_statements_present, true
      rescue Capistrano::CommandError
        puts "No after migration statements"
      end
    end

    desc "Execute Migration statements which were delayed to be executed after indexing"
    task :execute_delayed_custom_migrator, :roles => [:db] do
      run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} lhm:execute_after_migrate_statements"
    end

    desc "Cleanup leftover/old LHM tables"
    task :cleanup_lhm_tables, :roles => :db do
      run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} lhm:cleanup_lhm_tables"
    end

  end # namespace :chronus

  namespace :deploy do

    before "deploy:cold", "deploy:setup"
    before "deploy:cold", "chronus:setup"
    before "deploy:migrations", "chronus:cleanup_lhm_tables"
    before "deploy:finalize_update","chronus:setup_cred_path"
    before "deploy:finalize_update", "chronus:update_app_creds"
    before "deploy:finalize_update", "chronus:mobile:checkout"
    before "deploy:finalize_update", "deploy:bundle_install"
    before "deploy:finalize_update", "chronus:digest:set_env"
    before "deploy:finalize_update", "chronus:digest:es_index"
    before "deploy:finalize_update", "chronus:mobile:move_cordova_files_to_s3"
    before "deploy:finalize_update", "chronus:copy_locales_from_s3"
    before "chronus:copy_locales_from_s3", "chronus:backup_locales_from_phrase_to_production_project_and_s3"

    # Quiece all the background activities like delayed job, cron etc before updating the current app.
    # TODO : Investigate if there is a way to quiece cron jobs ??

    after "deploy:create_symlink", "deploy:make_script_files_executable"
    after "deploy:create_symlink", "chronus:pseudolocalize"
    after "deploy:rollback", "deploy:web:enable"
    before "deploy:update_code", "deploy:slack:notify_deploy_start"
    after  "deploy", "deploy:slack:notify_deploy_finish"
    after  "deploy:migrations", "deploy:slack:notify_deploy_finish"
    before "deploy:rollback", "deploy:slack:notify_deploy_failed"


    namespace :slack do

      def get_options_for_slack(deployment_action)
        if chronus_chef_deploy
          servers = find_servers_for_task(current_task).collect(&:host).uniq.join(",")
          return {:text => "Chef Deployment #{deployment_action}", :server => servers, :slack_url => SlackUtils::OPS_CHANNEL}
        else
          return {:text => "Mentor Deployment #{deployment_action}", :server => rails_env, :slack_url => SlackUtils::MENTOR_CHANNEL, :branch => branch}
        end
      end

      desc "deployment start notification to slack"
      task :notify_deploy_start do
        SlackUtils.send_slack_message(get_options_for_slack("Started").merge(:color => "warning"))
      end

      desc " deployment finish notification to slack"
      task :notify_deploy_finish do
        SlackUtils.send_slack_message(get_options_for_slack("Finished").merge(:color => "good"))
      end

      desc "deployment failure notification to slack"
      task :notify_deploy_failed do
        SlackUtils.send_slack_message(get_options_for_slack("Failed").merge(:color => "danger"))
      end

    end

    desc "get IPs for all the roles"
    task :get_ips do
      app_ips = roles[:app].collect(&:host)
      web_ips = roles[:web].collect(&:host)
      db_ip = roles[:db].collect(&:host)
      puts "All App Servers : " + app_ips.to_s
      puts "Primary App Server(Cron server) : " + db_ip.to_s
      puts "All Web Servers : " + web_ips.to_s
    end

    desc "Overwritten the default deploy task to account for digest changes #{deploy_help}"
    task :default do
      set :skip_migrations, true
      chronus_deploy
    end

    desc "Overwritten deploy:migrations task to account for digest changes #{deploy_help}"
    task :migrations do
      chronus_deploy
    end

    desc "[internal] standalone task for disaster recovery scenarios to replace ips in deploy.yml"
    task :update_ip do
      original_ip = ENV["ORIGINAL_IP"]
      backup_ip = ENV["BACKUP_IP"]
      data = File.read(DEPLOY_YML)
      filtered_data = data.gsub(original_ip,backup_ip)
      File.open(DEPLOY_YML, "w") do |f|
        f.write(filtered_data)
      end
    end

    desc "[internal] Custom deploy task to faciliate Zero downtime deployment"
    task :chronus_deploy do
      update_code
      chronus.delayed_job.stop if !skip_delayed_job_restart && skip_es_reindex
      chronus_migrate unless migrations_or_indexing_not_required
      create_symlink
      restart
      web.enable unless migrations_or_indexing_not_required
      chronus.memcached.restart unless skip_clear_cache #TODO: Is restart required, isn't flush sufficient http://dev.mensfeld.pl/2013/04/clear-memcached-without-restart-with-ruby-and-capistrano-rake-task/ #TODO: This should be before or after restart?
      chronus.cron_tasks.schedule
      chronus.delayed_job.start unless skip_delayed_job_restart
      chronus.cron_tasks.schedule
      #chronus.matching.index unless skip_match_indexing #not necessary as it is run as part of daily cron
      cleanup
      deploy.web.check_passenger_uptime
      newrelic.notice_deployment
      chronus.es_reindex.reindex_new if !skip_es_reindex && new_es_indexes_to_reindex && new_es_indexes_to_reindex.any?
      perform_recovery_setup unless skip_recovery_setup
    end

    desc "[internal] A custom task whic runs all data migrations & puts up a maintenance page during this process"
    task :chronus_migrate do
      migrate unless skip_migrations
      chronus.check_delayed_custom_migrator unless skip_migrations
      chronus.es_reindex.reindex unless skip_es_reindex
      chronus.delayed_job.stop if !skip_delayed_job_restart && !skip_es_reindex
      web.disable if maintenance_page_required
      chronus.es_reindex.flipping_es_indexes unless skip_es_reindex
      chronus.execute_delayed_custom_migrator if delayed_migrator_statements_present
    end

    task :update_server_role, :roles => [:web_admin, :app_admin] do
      setup_app_creds
      cold_ips = find_servers_for_task(current_task).collect(&:host)
      options = {region: region, access_key_id: dev_creds["S3_KEY"], secret_access_key: dev_creds["S3_SECRET"]}
      app_server_util = DeploymentUtils::AppServerUtils::Manager.new(rails_env, options)
      app_server_util.update_server_role_tag(cold_ips)
    end

    # Rake Tasks 
    desc <<-DESC
      Invoke the rake task by using task="<task_name>""
        e.g. cap <env> deploy:invoke task=db:seed
      Task will be run on app server only
    DESC
    task :invoke, :roles => :db do
      run "cd #{current_path} && #{rake} RAILS_ENV=#{rails_env} #{ENV['task']} --trace"
      run "cd #{current_path} && #{rake} RAILS_ENV=#{rails_env} deployment_rake_tasks:update_db TASK_NAME=\"#{ENV['task']}\""
    end

    desc "Execute after deployment rake tasks and mark their status"
    task :run_rake_tasks_from_db, :roles => :db do
      run "cd #{current_path} && #{rake} RAILS_ENV=#{rails_env} deployment_rake_tasks:execute --trace"
    end

    desc "Defines the variable to indicate whether the particular action is being invoked"
    task :set_deploy_env_for_roles do
      set :chronus_cold_deploy, cold_deploy?
      set :chronus_chef_deploy, chef_deploy?
      set :chronus_sftpserver_deploy, sftpserver_deploy?
    end

    desc "Starts the web app and the back ground processes : nginx, delayed_job"
    task :start, :roles => [:app_admin, :web_admin] do

      chronus.execute_delayed_custom_migrator if chronus_cold_deploy

      if chronus_cold_deploy
        deploy.web.start_only
      else
        deploy.web.start
      end

      # No need to start memcached during cold deploy since it will be started during boot process.
      chronus.memcached.start unless chronus_cold_deploy

      deploy.web.enable

      unless skip_delayed_job_restart
        if chronus_cold_deploy
          chronus.delayed_job.start_only
        else
          chronus.delayed_job.start
        end
      end

      update_server_role if chronus_cold_deploy

      # This is needed during during cold deploy since monit is assumed to be shutdown before cold deploy
      # We shutdown monit during cold depoy since none of the app bits will be available and there is no
      # point in monitoring app processes which are guaranteed to fail.
      chronus.monit.start_and_monitor if chronus_cold_deploy

      # We don't start cron since it is also used for DR drill during which we don't want any
      # emails to be sent to users present in production DB. Let us leave that as a manual operation
      puts "NOTE** : cron was not started automatically since you may be working with a DR drill"
      puts "If you are not doing DR drill and are SURE about starting cron you can use the below command to start it"
      puts "cap #{rails_env} chronus:cron:start"
    end

    desc "Stops the web app and the back ground processes  : nginx, delayed_job"
    task :stop, :roles => [:app_admin, :web_admin] do
      chronus.cron.stop
      chronus.delayed_job.stop unless skip_delayed_job_restart
      deploy.web.disable
      chronus.memcached.stop
      deploy.web.stop
    end

    desc "Stops the web app and the back ground processes  : nginx, delayed_job, and show maintenance page. Comes in handy for DR drills"
    task :stop_in_maintenance_mode, :roles => [:app_admin, :web_admin] do
      chronus.cron.stop
      chronus.delayed_job.stop unless skip_delayed_job_restart
      deploy.web.disable
      chronus.memcached.stop
      deploy.web.restart
    end

    desc "Installs gems using bundler"
    task :bundle_install, :roles => [:app_admin, :web_admin] do
      skipped_envs = %w(development test demo)
      skipped_envs.delete(rails_env)
      run "cd #{release_path} && sudo bundle install --gemfile #{release_path}/Gemfile --path /mnt/app/shared/bundle --deployment --without #{skipped_envs.join(" ")}"
      run "cd #{release_path} && sudo chown -R app:app #{release_path}/.bundle"
    end

    desc "Seed db"
    task :db_seed, :roles => :db do
      run "cd /mnt/app/current && #{rake} RAILS_ENV=#{rails_env} db:seed --trace"
    end

    desc "Compresses the JS and CSS files and sends them to s3"
    task :assets_precompile, :roles => :web_admin do
      run "cd #{release_path} && #{rake} RAILS_ENV=#{rails_env} assets:precompile"
    end

    desc "Make all files in the script directory executable"
    task :make_script_files_executable, :roles => [:app_admin, :web_admin] do
      sudo "chmod +x /mnt/app/current/script/*"
    end

    task :restart, :roles => :web_admin do
      sudo "passenger-config restart-app /mnt/app/current --rolling-restart --ignore-app-not-running"
    end

    desc "Take snapshot of /mnt ebs volume and attach to backup volume"
    task :perform_recovery_setup, :roles => [:web_admin, :app_admin] do
      perform_recovery_setup_app
      perform_recovery_setup_web unless is_collapsed_setup?
    end

    task :perform_recovery_setup_web, :roles => :web_admin do
        perform_recovery_setup_util
    end

    task :perform_recovery_setup_app, :roles => :app_admin do
        perform_recovery_setup_util
    end

    task :recover_web_server, :roles => :web_backup_admin do
      perform_recover_common
    end

    task :recover_secondary_app_server, :roles => :app_backup_admin do
      perform_recover_common
    end

    task :recover_primary_app_server, :roles => :app_backup_admin do
      perform_recover_common(primary: true)
    end

    task :recover_collapsed_server, :roles => :app_backup_admin do
      perform_recover_common(primary: true)
    end

    namespace :web do
      task :disable, :roles => :web do
      # invoke with
      # MAINTENANCE_TIME_UNTIL="16:00 EST" MAINTENANCE_REASON="a database upgrade" cap deploy:web:disable
        on_rollback { rm maintenance_page }
        deadline, reason= ENV['MAINTENANCE_TIME_UNTIL'], ENV['MAINTENANCE_REASON']
        env = rails_env
        maintenance = ERB.new(File.read("script/maint.html.erb")).result(binding)
        put maintenance, maintenance_page, :mode => 0644
      end

      task :enable, :roles => :web do
        run "rm -rf #{maintenance_page}"
      end

      task :start, :roles => :web_admin do
        deploy.web.start_only
        sudo "monit -g web monitor all"
      end

      task :start_only, :roles => :web_admin do
        sudo "/etc/init.d/nginx start"
      end

      task :restart, :roles => :web_admin do
        sudo "/etc/init.d/nginx restart"
      end

      task :check_passenger_uptime, :roles => :web_admin do
        retry_times = 0
        while retry_times < 5
          retry_times += 1
          passenger_uptime_array = []
          restart_status = 0
          run "sudo passenger-status | grep Uptime: | awk '{ print $9 }'" do |channel, stream, data|
            passenger_uptime_array += data.split("\r\n")
          end
          passenger_uptime_array.select! { |e| e.strip.to_s != "" }
          passenger_uptime_array.each do |uptime|
            restart_status = 1 if uptime[-1] == 'd' || uptime[-1] == 'h' || (uptime[-1] == 'm' && uptime.to_i > 15)
          end

          if restart_status == 1 && retry_times < 5
            sleep 5
            puts "Passenger Not Restarted Completely, Its retrying again".colorize(:red) 
          elsif restart_status == 1 && retry_times == 5
            puts "Error: Passenger Not Restarted Properly, There is some issue with rolling restart".colorize(:red)
            DeploymentHelper.send_developer_email("Error: ENV: #{rails_env}. Passenger Not Restarted Properly", "#{rails_env}: Passenger Not Restarted Properly, There is some issue with rolling restart", "email-monitoring@apollo.pagerduty.com")
          else
            break
          end
        end
      end 

      task :stop_only, :roles => :web_admin do
        sudo "/etc/init.d/nginx stop"
      end

      task :stop, :roles => :web_admin do
        sudo "monit -g web unmonitor all"
        sudo "/etc/init.d/nginx stop"
      end

      task :check_test_url do
        if DeploymentHelper.website_status(rails_env)
          puts "Website is up and running"
        else
          puts "Error: #{rails_env}: is down"
        end
      end
    end
  end
end
