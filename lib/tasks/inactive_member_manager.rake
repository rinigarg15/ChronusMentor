namespace :suspend_inactive_members do
	task :suspend! => :environment do
		ActionMailer::Base.perform_deliveries = false
		InactiveMemberManager.suspend!(ENV["FILE_PATH"])
	end
end