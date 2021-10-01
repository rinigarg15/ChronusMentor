namespace :single_time do
  # bundle exec rake single_time:update_notification_settings_as_daily DOMAIN='' SUBDOMAIN=''
  desc 'update program notification settings as daily for admin users'
  task :update_notification_settings_as_daily => :environment do
    Common::RakeModule::Utils.execute_task do
      organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"])[1]
      organization.programs.each do |program|
        puts "Updating notification setting of admin users in program #{program.root}"
        program.admin_users.update_all(program_notification_setting: UserConstants::DigestV2Setting::ProgramUpdates::DAILY, skip_delta_indexing: true)
      end
    end
  end

  # bundle exec rake single_time:update_group_notification_setting_as_daily DOMAIN='chronus.com' SUBDOMAIN='walkthru' ROOTS='p1,p2'
  desc 'update group notification setting as daily for all users who set it as weekly'
  task :update_group_notification_setting_as_daily => :environment do
    Common::RakeModule::Utils.execute_task do
      programs = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV['ROOTS'])[0]
      programs.each do |program|
        puts "Updating group notification setting of users in program #{program.root}"
        program.users.where(group_notification_setting: UserConstants::DigestV2Setting::GroupUpdates::WEEKLY).update_all(group_notification_setting: UserConstants::DigestV2Setting::GroupUpdates::DAILY, skip_delta_indexing: true)
      end
    end
  end
end