# This single time rake task is for updating delta jobs created during mongdb local to mongodb atlas migration
# <queue_name>_temp are the duplicate queue created during mongodb reindexing
#
namespace :single_time do
  desc "handle delta delayed jobs during mongodb atlas migrations"
  task update_delta_mongodb_delayed_job_entries: :environment do
    queue_hash = {"mongo_cache_high_load_temp" => "mongo_cache_high_load", "mongo_cache_temp" => "mongo_cache", "normal_temp" => nil}
    queue_hash.each do |temp_queue_name, queue_name|
      list_delta_jobs = Delayed::Job.where(queue: temp_queue_name)
      list_delta_jobs.each do |d_job|
        d_job.queue = queue_name
        d_job.save!
      end
      puts "Updated Delta Delayed Job: #{list_delta_jobs.size} Queue Name: #{queue_name.to_s}, during Mongodb Atlas migration"
    end
  end
end
