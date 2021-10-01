namespace :single_time do
  #usage: bundle exec rake single_time:populate_calendar_sync_count
  desc "Populate calendar sync count for members who hold this as nil to default(0)"
  task populate_calendar_sync_count: :environment do
    Member.where(calendar_sync_count: nil).update_all(calendar_sync_count: 0)
    puts "Done!"
  end
end
