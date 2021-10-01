# EXAMPLE: bundle exec rake single_time:purge_member_inboxes DOMAIN='localhost.com' SUBDOMAIN='ceg' ROOTS='p1,p2' DATE='13/09/2018' ADMIN_MESSAGE_IDS='123,456,789'

namespace :single_time do
  task purge_member_inboxes: :environment do
    Common::RakeModule::Utils.execute_task do
      programs, organization = Common::RakeModule::Utils.fetch_programs_and_organization(ENV["DOMAIN"], ENV["SUBDOMAIN"], ENV["ROOTS"])
      member_ids = User.where(program_id: programs.collect(&:id)).where("created_at >= ?", ENV["DATE"].to_date.beginning_of_day).pluck(:member_id).uniq
      message_ids = AdminMessage.where(id: ENV['ADMIN_MESSAGE_IDS'].split(',').collect(&:to_i), program_id: programs.collect(&:id)).pluck(:id)
      AbstractMessageReceiver.where.not(status: AbstractMessageReceiver::Status::DELETED).where(member_id: member_ids, message_id: message_ids).update_all(status: AbstractMessageReceiver::Status::DELETED)
    end
  end
end
