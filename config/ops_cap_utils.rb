require File.dirname(__FILE__) + '/../script/lib/deployment_utils/restart_utils'

Capistrano::Configuration.instance.load do

  def handle_patches_for_multi_web_server_architecture(restart_util)
    restart_util.restart_app_servers
    restart_util.restart_web_servers_one_by_one
  end

  def handle_patches_for_single_web_server_architecture(restart_util)
    restart_util.restart_app_servers unless is_collapsed_setup?
    restart_util.start_backup_instance
    wait_till_process_running("nginx", :web_backup)
    #To prevent Delayed jobs from starting for collapsed servers, stop monit
    sudo "service monit stop", roles: :web_backup_admin
    restart_util.switch_instances
    restart_util.restart_web_or_collapsed_server
    wait_till_process_running("nginx", :web)
    restart_util.revert_switch_instances
    restart_util.stop_backup_instance
  end

  def handle_patches_for_non_elb_single_servers(restart_util)
    restart_util.restart_web_or_collapsed_server
  end

  def wait_till_process_running(process, role)
    max_timeout = 150
    counter = 0
    process_capture = ""
    while counter < max_timeout && process_capture.empty?
      begin
        process_capture = capture "ps aux | grep #{process} | grep -v grep || true", roles: role
      rescue => e
        teardown_connections_to(sessions.keys) #To reset connection after restart
        puts "Error: #{e.message}. Retrying"
      ensure
        counter += 1
        sleep 2
      end
    end
    raise "process #{process} not started yet" if process_capture.empty?
  end

  def check_no_critical_tasks_running
    critical_tasks = ["rake", "cron.hourly", "cron.daily", "delayed_job"]
    process_lists = {}
    max_timeout = 20
    counter = 0
    while counter < max_timeout
      find_servers_for_task(current_task).each do |server|
        process_lists[server.host] = (capture "ps aux | grep -E '#{critical_tasks.join('|')}' | grep -v grep || true", :hosts => server.host)
      end
      # return if no critical processes are running
      return true if (process_lists.values.select{|w| !w.empty?}.count == 0)
      counter += 1
      puts "Some processes are still running. Retrying in 30 seconds.\n#{process_lists}"
      sleep 30
    end
    raise "Stopping patches. Some processes are still running. Try again after some time. Details: #{process_lists}"
  end
  namespace :chronus do

    task :security_patches, :roles => [:app_admin, :web_admin] do
      role_ips = Hash.new
      [:app, :web, :web_backup].each{|sever_type| role_ips[sever_type] = roles[sever_type].collect(&:host)}
      options = {region: region, access_key_id: dev_creds["S3_KEY"], secret_access_key: dev_creds["S3_SECRET"], role_ips: role_ips}
      restart_util = DeploymentUtils::RestartUtils::Manager.new(rails_env, options)
      begin
        chronus.delayed_job.stop
        #Wait for the Delayed job and Crons to stop
        check_no_critical_tasks_running
        #If there is not backup server, just restart the collapsed server
        if role_ips[:web_backup].empty?
          handle_patches_for_non_elb_single_servers(restart_util)
        #If there is single web/collapsed server, we need to switch with the backup server and revert back.
        #If there are multiple web servers, just deregister and restart servers one by one
        else
          (role_ips[:web].count > 1) ? handle_patches_for_multi_web_server_architecture(restart_util) : handle_patches_for_single_web_server_architecture(restart_util)
        end
      rescue => e
        puts "Error: #{e.message}"
      ensure
        teardown_connections_to(sessions.keys) #To reset connection after restart
        chronus.delayed_job.start
        chronus.cron.start
        # Check the website to see if it is up and not in maintenance
        deploy.web.check_test_url
      end
      puts "Security Upgrades are done! Please check if monit is running"
    end

    namespace :ops do
      desc "Rotate mentor admin"
      task :update_mentoradmin_password, :roles => :web do 
        run "cd /mnt/app/current && bundle exec rake RAILS_ENV=#{rails_env} ops:update_mentoradmin_password" do |ch, stream, data|
          if data =~ /Enter the new MentorAdmin Password:/
            ch.send_data(Capistrano::CLI.password_prompt("New MentorAdmin Password: ") + "\n")
          elsif data =~ /Retype Password:/
            ch.send_data(Capistrano::CLI.password_prompt("Re-type mentoradmin password: ") + "\n")
          else
            Capistrano::Configuration.default_io_proc.call(ch, stream, data)
          end
        end
      end
    end
  end
 end