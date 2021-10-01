# Usage: rake user_activities:export_csv
namespace :user_activities do
  desc "Exports data in user activities as a CSV"

  task :export_csv => :environment do
    file_path = "#{Rails.root.to_s}/tmp/user_activities_#{Time.now.to_i}.csv"
    UserActivity.export_to_csv(file_path)
  end
end