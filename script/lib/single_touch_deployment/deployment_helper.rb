require 'gmail'
require 'open3'
require 'colorize'
require 'mail'
require_relative './deployment_constants'
require_relative './step_checker'
require_relative './deployment_module_helper'
require_relative './service_maintenance'
require_relative './deployment_s3_logs.rb'

class DeploymentHelper
  include DeploymentConstants
  extend DeploymentModuleHelper

  def self.my_system_cmd(cmd, env_name = "default", abort_flag = true, file_name = nil)
    if file_name
      file_obj = File.open("/tmp/#{file_name}", "w")
      status, failure_backtrace_log = popen3_cmd(cmd, env_name, file_obj)
      file_obj.close
    else
      status, failure_backtrace_log = popen3_cmd(cmd, env_name)
    end
    send_developer_email("Failed: #{cmd}", failure_backtrace_log) unless status == 1
    return status unless abort_flag == true
    abort("ERROR: ENV: #{env_name} Aborting: #{cmd}".colorize(:color => :red)) unless status == 1
    return status
  end

  def self.popen3_cmd(cmd, env_name = "default", file_obj = nil)
    exe_cmd = ""
    error_arr = Array.new
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      still_open = [stdout, stderr]
      while !still_open.empty?
        print "#{env_name}: ".colorize(:color => ENV_COLOR[env_name]) if env_name != "default"
        fhs = select(still_open, nil, nil, nil)
        if fhs[0].include? stdout
          begin
            line = stdout.readline()
            writting_stdout_stderr(line, file_obj, exe_cmd, error_arr)
          rescue EOFError
            still_open.delete_if {|s| s == stdout}
          end
        end
        if fhs[0].include? stderr
          begin
            line = stderr.readline()
            writting_stdout_stderr(line, file_obj, exe_cmd, error_arr)
          rescue EOFError 
            still_open.delete_if {|s| s == stderr}
          end
        end
      end
      exit_status = wait_thr.value
      unless exit_status.success?
        return 0, "Error: FAILED !!! #{cmd} Executing: #{exe_cmd}  Reason: #{error_arr.join("")}"
      end
    end
    return 1, "Finished: #{cmd}"
  end

  def self.writting_stdout_stderr(line, file_obj, exe_cmd, error_arr)
    if line.include? "executing"
      print line.colorize(:color => :green)
      exe_cmd = line 
      error_arr = []
    else
      puts line
      error_arr.push(line)
    end
    file_obj << line if file_obj
  end

  def self.run_cap_deploy(env_name, deployment_args, timestamp, abort_flag = true)
    status = my_system_cmd("cap #{env_name} deploy:migrations #{deployment_args}", env_name, abort_flag, "deployment-#{env_name}-#{timestamp}.log")
    StepChecker.update_file(:completed_deployment, env_name) if status == 1
    stop_service_maintenance if status != 1
    return status
  end

  def self.cap_parallel_deploy(deploy_status, prod_env_array, timestamp, deployment_args)
    env_array = Array.new(prod_env_array.size)
    (1...prod_env_array.size).each{ |i| env_array[i] = Thread.new{ deploy_status[i] = self.run_cap_deploy(prod_env_array[i], deployment_args, timestamp, false) } }
    (1...prod_env_array.size).each{ |i| env_array[i].join }
  end

  def self.run_deployment_rake(env_name, timestamp, abort_flag = true)
    status = my_system_cmd("cap #{env_name} deploy:run_rake_tasks_from_db", env_name, abort_flag, "rake-#{env_name}-#{timestamp}.log")
    StepChecker.update_file(:completed_rake_tasks, env_name) if status == 1
    stop_service_maintenance if status != 1
    return status
  end

  def self.cap_parallel_rake(deploy_status, prod_env_array, timestamp)
    env_array = Array.new(prod_env_array.size)
    (1...prod_env_array.size).each{ |i| env_array[i] = Thread.new{ self.run_deployment_rake(prod_env_array[i], timestamp, false) if deploy_status[i] == 1 } }
    (1...prod_env_array.size).each{ |i| env_array[i].join if deploy_status[i] == 1 }
  end

  def self.run_recovery_setup(env_name, abort_flag = true)
    status = my_system_cmd("cap #{env_name} deploy:perform_recovery_setup", env_name, abort_flag)
    StepChecker.update_file(:perform_recovery_setup, env_name) if status == 1
    return status
  end

  def self.cap_perform_recovery_setup(prod_env_array)
    env_array = Array.new(prod_env_array.size)
    (0...prod_env_array.size).each{ |i| env_array[i] = Thread.new{ self.run_recovery_setup(prod_env_array[i], false) } }
    (0...prod_env_array.size).each{ |i| env_array[i].join }
  end

  def self.website_status(env_name)
    file_path = "#{File.dirname(__FILE__)}/../../../config/environments/#{env_name}.rb"
    retry_when_exception("Check website status Manually") do
      rails_env_constants = Hash[File.read(file_path).scan(/([A-Z_]+) = (.+)/)]
      if rails_env_constants['EMAIL_MONITOR_ORG_URL']
        url = rails_env_constants['EMAIL_MONITOR_ORG_URL'].gsub('"','')
        res = Net::HTTP.get_response(URI.parse(url))
        if res['location']
          url = res['location']
        end
        url = URI.parse(url)
        contents = Net::HTTP.get(url)
        if contents.include?("login")
          return true
        else
          return false
        end
      else
        puts "#{env_name}: No url setup for the given environment".colorize(:color => :red)
        return false
      end
    end
  end

  def self.check_web_status(env_array)
    env_array.each do |env_name|
      unless self.website_status(env_name)
        puts "Error: #{env_name}: is down".colorize(:color => :red)
        stop_service_maintenance
        send_developer_email("Deployment Error: #{env_name} is down", "Check website manually")
      else
        puts "#{env_name}: Website is up and running".colorize(:color => :green)
      end
    end
  end

  def self.stop_service_maintenance(maintenance_id_arr = StepChecker.get_value(:start_maintenance))
    maintenance_id_arr.each { |id| ServiceMaintenance.new.stop_maintenance(id) }
  end

  def self.send_developer_email(subject_text, body_text="", receiver_id = RECEIVER_EMAIL_ID)
    puts "sending mail to developers"
    counter = 0
    begin
      counter += 1
      mail = Mail.new do
        from     SENDER_EMAIL_ID
        to       receiver_id
        subject  subject_text
        body     body_text
      end
      mail.deliver!
    rescue => e
      if counter <= EMAIL_RETRY_TIMES
        sleep EMAIL_RETRY_INTERVAL
        retry
      else
        puts "ERROR: Sending Email Failed\n#{subject_text}\n#{body_text}".colorize(:red)
      end
    end
  end

  def self.get_log_path(env_name, timestamp, tag_name)
    "/tmp/#{tag_name}-#{env_name}-#{timestamp}.log"
  end

  def self.store_failed_logs(prod_env_array, timestamp, tag_symbol, tag_name)
    (prod_env_array - StepChecker.get_value(tag_symbol)).each do |env_name|
      if File.exist?(get_log_path(env_name, timestamp, tag_name))
        modified_timestamp = timestamp + "-failed"
        system("cp #{get_log_path(env_name, timestamp, tag_name)} #{get_log_path(env_name, modified_timestamp, tag_name)}")
        DeploymentS3Logs.new.upload_logs_s3(env_name, modified_timestamp, tag_name)
      end
    end
  end

  def self.git_diff_present(develop_branch, master_branch)
    !(%x[git diff origin/#{master_branch} origin/#{develop_branch} --name-only].empty?)
  end

  def self.get_git_branches(prod_env_array) #will always include develop branch
    git_branches = [DEVELOP_BRANCH]
    prod_env_array.each do |env_name|
      BRANCH_ENV.each do |branch_name, env_array|
        git_branches.push(branch_name) if env_array.include?(env_name)
      end
    end
    git_branches.uniq
  end

  def self.diff_present_check(git_branches)
    failed_branches = []
    git_branches.each do |develop_branch|
      unless git_diff_present(develop_branch, GIT_DEVELOP_MASTER[develop_branch])
        if develop_branch == DEVELOP_BRANCH
          send_developer_email("No Deployment Today, Develop Unblocked", "Reason: No diff between #{MASTER_BRANCH} and #{DEVELOP_BRANCH}")
          abort("Aborting: No diff between #{MASTER_BRANCH} and #{DEVELOP_BRANCH}".colorize(:color => :green))
        else
          failed_branches.push(develop_branch)
          send_developer_email("Latest Changes are not merged to #{develop_branch}. No deployment to #{BRANCH_ENV[develop_branch]} today.", "Please make sure if you are making changes to develop, make those changes to other branches like #{develop_branch}, etc.")
        end
      else
        StepChecker.update_file(:diff_present_checker, develop_branch)
      end
    end
    git_branches - failed_branches
  end

  def self.pull_latest_develop(git_branches)
    puts "Pulling_latest develop branches"
    failed_branches = []
    git_branches.reverse_each do |develop_branch|
      begin
        my_system_cmd "git checkout #{develop_branch}"
        my_system_cmd "git fetch origin"
        my_system_cmd "git pull origin #{develop_branch}"
        my_system_cmd "git diff #{develop_branch} origin/#{develop_branch} --name-only --exit-code"
      rescue => e
        abort("Error: #{e.message}").colorize(:color => :red) if develop_branch == DEVELOP_BRANCH
        failed_branches.push(develop_branch)
      end
    end
    git_branches - failed_branches
  end

  def self.master_develop_create_diff_file(timestamp)
    puts "Creating diff file of Master-Develop"
    my_system_cmd "git checkout #{MASTER_BRANCH}"
    my_system_cmd "git pull origin #{MASTER_BRANCH}"
    my_system_cmd "git checkout #{DEVELOP_BRANCH}"
    my_system_cmd "git diff #{MASTER_BRANCH} #{DEVELOP_BRANCH} --no-ext-diff --full-index > /tmp/#{MASTER_BRANCH}_#{DEVELOP_BRANCH}_diff_#{timestamp}.txt"
  end

  def self.merge_latest_develop_with_master(git_branches)
    puts "Merge latest Develops with their respective Masters"
    failed_branches = []
    git_branches.reverse_each do |develop_branch|
      begin
        my_system_cmd "git checkout #{GIT_DEVELOP_MASTER[develop_branch]}"
        my_system_cmd "git pull origin #{GIT_DEVELOP_MASTER[develop_branch]}"
        my_system_cmd "git diff #{GIT_DEVELOP_MASTER[develop_branch]} origin/#{GIT_DEVELOP_MASTER[develop_branch]} --name-only --exit-code"
        if my_system_cmd("git merge #{develop_branch} --no-edit", "default", false) == 0
          my_system_cmd "git merge --abort"
          abort("Error: Merge Conflict".colorize(:color => :red))
        end
        my_system_cmd "git push origin #{GIT_DEVELOP_MASTER[develop_branch]}"
      rescue => e
        abort("Error: #{e.message}").colorize(:color => :red) if develop_branch == DEVELOP_BRANCH
        failed_branches.push(develop_branch)
      end
    end
    git_branches - failed_branches
  end
end