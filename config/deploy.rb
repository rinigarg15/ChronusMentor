set :application, "groups"
set :repository,  "git@github.com:ChronusCorp/ChronusMentor.git"
set :scm, :git
set :runner, "root"
set :use_sudo, false
set :deploy_via, :checkout
set :git_shallow_clone, 1
set :deploy_to, "/mnt/app"
set :user, "app"
set(:rails_env) { current_deploy_mode }
set :shared_children, %w(public/system log tmp/pids)
set :app_creds, {}
set :ssh_options, { verify_host_key: false }
default_run_options[:pty] = true

# Your EC2 instances. Use the ec2-xxx....amazonaws.com hostname, not
# any other name (in case you have your own DNS alias) or it won't
# be able to resolve to the internal IP address.

# The real roles are set when we a task "with" an environment.
# This is done to prevent actions like "cap deploy". One should rather
# say "cap staging deploy" or "cap production deploy".
role :web, "0.0.0.0"
role :app, "0.0.0.0"
role :db, "0.0.0.0"
role :memcache, "0.0.0.0"
role :sftpserver, "0.0.0.0"

namespace :db do
  desc 'Dumps the production database to db/production_data.sql on the remote server'
  task :remote_db_dump, :roles => :db, :only => { :primary => true } do
    run "cd #{deploy_to}/#{current_dir} && " +
      "rake RAILS_ENV=#{rails_env} db:database_dump --trace"
  end

  desc 'Downloads db/production_data.sql from the remote production environment to your local machine'
  task :remote_db_download, :roles => :db, :only => { :primary => true } do
    execute_on_servers(options) do |servers|
      self.sessions[servers.first].sftp.connect do |tsftp|
        tsftp.download!("#{deploy_to}/#{current_dir}/db/production_data.sql", "db/production_data.sql")
      end
    end
  end

  desc 'Cleans up data dump file'
  task :remote_db_cleanup, :roles => :db, :only => { :primary => true } do
    execute_on_servers(options) do |servers|
      self.sessions[servers.first].sftp.connect do |tsftp|
        tsftp.remove! "#{deploy_to}/#{current_dir}/db/production_data.sql"
      end
    end
  end

  desc 'Dumps, downloads and then cleans up the production data dump'
  task :remote_db_runner do
    remote_db_dump
    remote_db_download
    remote_db_cleanup
  end
end
