namespace :deployment_rake_tasks do
  desc "Fetch and execute rake tasks which are in PENDING state"
  task :execute => :environment do
    DeploymentRakeRunner.fetch_and_execute
  end

  task :update_db => :environment do
    ChrRakeTasks.create(name: ENV['TASK_NAME'], status: ChrRakeTasks::Status::SUCCESS)
  end
end