namespace :performance_scrap_populator do

  # Note: 
  # 1. This task is meant to be pushed only to performance environment (uncomment) - to correct the populator
  # 2. We will have to comment out AddScrapsToMessages migration in performance database before running this task
  #     OR
  #     run `MentoringAreaScrap.delete_all` in performance console before db:migrate or deploying this
  desc "Create new scraps for performance"
  task create: :environment do
    scraps_populator = PerformancePopulator.new 

    ActionMailer::Base.perform_deliveries = false
    previous_level = Rails.logger.level
    Rails.logger.level = Logger::FATAL
    ActiveRecord::Base.transaction do
      Program.all.each do |program|
        scraps_populator.populate_bulk_scraps(program)
      end
    end
    ActionMailer::Base.perform_deliveries = true
    Rails.logger.level = previous_level
  end
end
