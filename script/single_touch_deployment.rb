#!/usr/bin/ruby
require 'colorize'
require 'trollop'
require 'dotenv'
require 'fileutils'
require_relative './lib/single_touch_deployment/deployment_constants'
require_relative './lib/single_touch_deployment/code_review'
require_relative './lib/single_touch_deployment/build_status'
require_relative './lib/single_touch_deployment/deployment_helper'
require_relative './lib/single_touch_deployment/service_maintenance'
require_relative './lib/single_touch_deployment/deployment_s3_logs'
require_relative './lib/single_touch_deployment/step_checker'

include DeploymentConstants

Dotenv.load(ENV_VARIABLES_PATH) if File.exists?(ENV_VARIABLES_PATH)

SUB_COMMANDS = %w(arg)

global_opts = Trollop::options do
  version "#{PROG_NAME} 1.0 (c) 2017 Chronus"
  banner <<-EOS
#{PROG_NAME} is a utility script which is designed to automate deployment. Supported operations are #{SUB_COMMANDS}
Usage:
       #{PROG_NAME} [options]
where [options] are:
EOS

  opt :env, "Run only Environments(-e demo,production..etc). By Default it is (-e demo,veteransadmin,production,productioneu) NOTE: no space after or before commas",
        :short => "-e", :type => :string

  opt :skip_env, "For Environment where we don't want deployment(-r demo,..etc), demo will be excluded during deployment. NOTE: no space after or before commas",
        :short => "-s", :type => :string

  opt :retry_if_deployment_failed, "If deployment failed, Start from where it failed", :short => "-r", :type => :boolean
  stop_on SUB_COMMANDS
end

cmd = ARGV.shift # get the subcommand
cmd = "list" if cmd.nil?
cmd_opts = case cmd
  when "arg"
    Trollop::options do
      opt :skip_build_check, "Don't give this option untill its very necessary, It will skip build check", :type => :boolean

      opt :force_full_deployment, "Will take the full deployment route if there is no migrations", :type => :boolean

      opt :skip_match_indexing, "Skip scheduling matching indexing task. Note: Will run as part of cron (6 hours)", :type => :boolean

      opt :full_es_reindex, "Complete Elasticsearch Indexing", :type => :boolean

      opt :skip_es_reindex, "Skip es reindexing", :type => :boolean

      opt :skip_delayed_job_restart, "Skip all dj related tasks. Note: Will be started by monit later", :type => :boolean

      opt :skip_clear_cache, "Skip memcache clear cache", :type => :boolean

      opt :skip_recovery_setup, "Skip recovery setup", :type => :boolean

      opt :perform_match_indexing_now, "Run matching indexing immediately instead of running it in DJ", :type => :boolean

      opt :skip_abort_deployment, "Skipping Deployment abort due to diff checks during code review", :type => :boolean
    end
  when "list"
  else
    Trollop::die "unknown subcommand #{cmd.inspect}"
  end

cmd_opts = {} if cmd_opts.nil?

prod_env_array = PROD_ENV
prod_env_array = global_opts[:env].split(",") if global_opts[:env]
prod_env_array = prod_env_array - global_opts[:skip_env].split(",") if global_opts[:skip_env]
skip_abort_deployment = cmd_opts[:skip_abort_deployment]
arg_array = []
arg_array.push("SKIP_RECOVERY_SETUP=true")
cmd_opts.select{ |key, val| val==true }.each{ |key, val| arg_array.push DEPLOYMENT_ENV_VAR[key]+"=true" if DEPLOYMENT_ENV_VAR[key] }
deployment_args = arg_array.join(" ")

retrying_deployment = global_opts[:retry_if_deployment_failed]

unless retrying_deployment
  if File.exist?(RETRY_DEPLOYMENT_STEPS_FILE) #if someone misses to retry while retrying
    log_steps = "/tmp/last_deployment_steps-" + Time.now.to_s.gsub(' ', '-') + ".txt"
    system("cp #{RETRY_DEPLOYMENT_STEPS_FILE} #{log_steps}")
    StepChecker.write_retry_file(StepChecker.new_dictionary_value)
  else
    StepChecker.write_retry_file(StepChecker.new_dictionary_value)
    FileUtils.chmod 0777, RETRY_DEPLOYMENT_STEPS_FILE
  end
end

puts "Started At #{Time.now}"

timestamp = StepChecker.get_value(:timestamp)
if timestamp.empty?
  timestamp = Time.now.to_s.gsub(' ', '-')
  StepChecker.update_file(:timestamp, timestamp)
end

#Upload logs of failed deployment. Retry should be specified
if retrying_deployment
  DeploymentHelper.store_failed_logs(prod_env_array, timestamp, :completed_deployment, "deployment")
  DeploymentHelper.store_failed_logs(prod_env_array, timestamp, :completed_rake_tasks, "rake")
  prod_env_array -= StepChecker.get_value(:completed_deployment)
end

#Step 1: Send Developers Mail(Deployment Started)
unless StepChecker.get_value(:send_mail)
  DeploymentHelper.send_developer_email("Starting Deployment Process(Environments: #{prod_env_array.join(",")}), Don’t push to Develop")
  StepChecker.update_file(:send_mail, true)
end

git_branches = DeploymentHelper.get_git_branches(prod_env_array)

#Step 2: Solano Develop Check
if (!StepChecker.get_value(:verify_build_check) && !cmd_opts[:skip_build_check])
  build_status = BuildStatus.new.check_build_passed(git_branches)
  successful_builds = git_branches.each_with_index.select{ |branch_name, i| build_status[i]}.map &:first 
  #If develop build fails, aborting the whole deployment and if some other build fails, skipping the deployment for those environments and continuing with the rest. The deployment for (successful_builds) branch/branches will continue.
  unless build_status[0]
    DeploymentHelper.send_developer_email("Aborting Deployment: Solano check Failed. Branches: #{git_branches - successful_builds}", "Fix the build and run script again")
    abort("Aborting: Solano check Failed. Branches: #{git_branches - successful_builds}".colorize(:color => :red))
  end
  DeploymentHelper.send_developer_email("Solano check Failed. Branches: #{git_branches - successful_builds}", "Fix the build and run script again") if build_status.include? false
  git_branches = successful_builds
  StepChecker.update_file(:verify_build_check, true) unless build_status.include? false
end                                

#Step 3: Pull the latest code in Develop and put the diff between Develop and Master for review
git_branches = DeploymentHelper.pull_latest_develop(git_branches)

#Step 4: Create diff file
if !StepChecker.get_value(:diff_master_develop)
  DeploymentHelper.master_develop_create_diff_file(timestamp)
  git_branches = DeploymentHelper.diff_present_check(git_branches)
  StepChecker.update_file(:diff_master_develop, true)
elsif retrying_deployment
  pending_branches = git_branches - StepChecker.get_value(:diff_present_checker)
  pending_branches_with_no_diff = pending_branches - DeploymentHelper.diff_present_check(pending_branches)
  git_branches -= pending_branches_with_no_diff
end

#Step 5: Create crucible review
unless StepChecker.get_value(:create_review)                             
  CodeReview.new.create_review(timestamp, skip_abort_deployment)
  StepChecker.update_file(:create_review, true)
end

#Step 6: Merge develop and master
git_branches = DeploymentHelper.merge_latest_develop_with_master(git_branches)

#Get environments to deploy
(GIT_DEVELOP_MASTER.keys - git_branches).each do |branch_name|
  prod_env_array -= BRANCH_ENV[branch_name]
end

if prod_env_array.size > 0
  DeploymentHelper.send_developer_email("Deploying to (Environments: #{prod_env_array.join(",")})") 
else
  DeploymentHelper.send_developer_email("No deployment. Aborting the process.", "Reason: prod_env_array is empty")
  abort("Reason: prod_env_array is empty").colorize(:color => :red)
end

#Step 7: pagerduty maintenance
maintenance_id_arr = ServiceMaintenance.new.pagerduty_maintenance
StepChecker.update_file(:start_maintenance, maintenance_id_arr)
 
begin
  deployment_env_array = prod_env_array - StepChecker.get_value(:completed_deployment)

  #Step 8: Deployment and Rake tasks. First environment(here its Demo)
  if deployment_env_array[0]
    puts "Started #{deployment_env_array[0]} Deployment"
    DeploymentHelper.run_cap_deploy(deployment_env_array[0], deployment_args, timestamp, true)

    puts "Running rake tasks in #{deployment_env_array[0]} if present"
    DeploymentHelper.run_deployment_rake(deployment_env_array[0], timestamp, true)

    puts "Status of #{deployment_env_array[0]}"
    DeploymentHelper.check_web_status(deployment_env_array[0...1])
  end

  deploy_status = Array.new(deployment_env_array.size, 0)
  deploy_status[0] = 1 if deploy_status.size > 0

  #Step 9: Others: Parallel Deployment
  puts "Started Parallel Deployment"
  DeploymentHelper.cap_parallel_deploy(deploy_status, deployment_env_array, timestamp, deployment_args)

  #Step 10: Parallel Rake Tasks
  puts "Running parallel rake tasks if present" 
  DeploymentHelper.cap_parallel_rake(deploy_status, deployment_env_array, timestamp)

  #Step 11: Ping url and check website is up or not
  puts "Status of websites"
  DeploymentHelper.check_web_status(deployment_env_array[1...deployment_env_array.size]) if deployment_env_array.size > 1

  #Step 12: Store logs for deployment and push it to S3
  success_deployment_envs = deployment_env_array.each_with_index.select { |env_name, i| deploy_status[i] == 1}.map(&:first)
  success_deployment_envs.each do |env_name| 
    DeploymentS3Logs.new.upload_logs_s3(env_name, timestamp, "deployment")
    DeploymentS3Logs.new.upload_logs_s3(env_name, timestamp, "rake") 
    StepChecker.update_file(:store_logs, env_name)
  end
rescue => e
  raise e
ensure 
  #Step 13: Stop Pagerduty Maintenance
  DeploymentHelper.stop_service_maintenance(maintenance_id_arr)
end

#Step 14: Perform Recovery Setup
unless cmd_opts[:skip_recovery_setup]
  DeploymentHelper.cap_perform_recovery_setup(success_deployment_envs)
end

#Step 15: Send Developers Mail(Deployment Finished)
DeploymentHelper.send_developer_email("Finished Deployment Process( Environments: #{success_deployment_envs.join(",")} )")

puts "End at #{Time.now}"
