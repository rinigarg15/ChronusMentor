# instructions to run #
#############################
# install git gem using 'gem install git'
# enable solano run for the target branch (which is your <branch_name>_cucumbers) from ci.solanolabs.com
# ensure git credentials are set properly in config
# run as 'ruby tddium_cucumber_branch_build.rb -o <branch_name> -f <path_to_local_repository>'
# default branch is develop and the corresponding cucumber branch is develop_cucumbers
#############################

require 'fileutils'
require 'rubygems'
require 'yaml'
require 'optparse'
require 'git'

options={}
OptionParser.new do |opts|
  opts.banner="Usage: tddium_cucumber_branch_build.rb [options]"
  opts.on("-o","--origin [branch_name]","origin branch name for which cucumbers are to run") do |origin_branch_name|
    @cucumber_origin_branches = origin_branch_name.split(",")
  end
  opts.on("-f","--folder [path_to_folder]","path to the folder where the repository is already present or is to be created") do |path|
    @directory=path
  end
  opts.on_tail("-h","--help","Display this screen")do
  puts opts
  exit
  end
end.parse!

@directory ||= "/mnt/app/cucumbers"
@cucumber_origin_branches ||= ["develop"]

git = Git.init

unless File.directory?(@directory)
  Dir.mkdir(File.join(@directory))
  puts "Creating clone"
  begin
    git = Git.clone("git@github.com:ChronusCorp/ChronusMentor.git", @directory)
    puts "Clone created"
  rescue Exception => e
    puts "Folder removed as clone failed."
    Dir.rmdir(File.join(directory))
  end
else
  git = Git.init(@directory)
  git.fetch
end

@cucumber_origin_branches.each do |branch|
  cucumber_branch = "#{branch}_cucumbers"

  puts "Checkout #{branch}"
    git.checkout(branch)
    puts git.pull("git@github.com:ChronusCorp/ChronusMentor.git", branch)

  puts "Remove #{branch}_cucumbers from remote and local"
    if git.branches.remote.collect(&:name).include?(cucumber_branch)
      git.push('origin', ":#{cucumber_branch}")
    end
    if git.branches.local.collect(&:name).include?(cucumber_branch)
      git.branch(cucumber_branch).delete
    end

  puts "Checkout new #{cucumber_branch} from #{branch}"
    git.branch(cucumber_branch).checkout

  puts "Change solano file"
    data = YAML.load_file(@directory + "/config/solano.yml")
    data["solano"]["hooks"] = {
      worker_setup: "RAILS_ENV=test bundle exec rake db:generate_fixtures matching:clear_and_full_index_and_refresh es_indexes:full_indexing;",
      post_worker: "(cd test && tar cf $HOME/results/$TDDIUM_SESSION_ID/session/fillin_screenshots.tgz fillin_screenshots)"
    }
    data["solano"]["test_pattern"] = ["features/*.feature"]
    data["solano"]["headless"] = true
    data["solano"]["isolate"] = ["features/admin_bulk_match.feature","features/cd_admin_action_2.feature","features/feature_mentoring_connection_v2_enduser_1.feature","features/feature_preferred_mentors.feature","features/feature_manage_members_in_connection_1.feature","features/admin_manage_connections.feature","features/admin_manage_connections_part2.feature","features/admin_recommendation.feature","features/mentee_request_mentor_from_admin_without_preference.feature","features/program_management_report_tour.feature","features/sub_program_admin.feature","features/filters_usage.feature","features/meetings.feature","features/feature_membership_eligibility_rules.feature","features/user_edit_profile.feature"]
    data["solano"]["runners"] = { "cucumber" => { "strict" => true } }
    data["solano"].delete("tests")
    data["solano"].delete("scheduler")

    File.open(@directory.to_s + "/config/solano.yml", 'w') { |f| YAML.dump(data, f) }
    git.add(@directory.to_s + "/config/solano.yml")

  puts "Changing test.rb"
    test_env=File.read(@directory+"/config/environments/test.rb")
    test_env.gsub!("config.whiny_nils = true","config.whiny_nils = true\nconfig.assets.compile = true\nconfig.assets.compress = false\nconfig.assets.debug = false\nconfig.assets.digest = true\n")
    test_env.gsub!("config.action_controller.asset_host = Proc.new do |*args|\n    _file_name, req = args\n    TEST_ASSET_HOST unless req.nil?\n  end\n\n","if !ENV['TDDIUM']\n config.action_controller.asset_host = Proc.new do |*args|\n    _file_name, req = args\n    TEST_ASSET_HOST unless req.nil?\n  end\n\nend\n\n")
    File.open(@directory+"/config/environments/test.rb","w"){ |file| file.puts test_env}
    git.add(@directory.to_s+"/config/environments/test.rb")
    git.commit("Running cucumber tests on #{Time.now.to_datetime}")

  puts "Pushing #{cucumber_branch} to remote"
    git.push('origin', cucumber_branch)
end
