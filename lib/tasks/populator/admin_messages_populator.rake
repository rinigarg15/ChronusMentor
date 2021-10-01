ORG_ADMIN_MESSAGES_COUNT = 10000
MAX_RECEIVERS_PER_MESSAGE = 10
# Note:
  # 1. This task is meant to be pushed only to performance environment.
  # 2. and it is being used to create only organization admin messages
namespace :admin_messages_populator do
  desc "Populate Admin Messages for Organization for performance"
  task create_for_performance: :environment do

    require 'faker'
    require 'populator'

    ActionMailer::Base.perform_deliveries = false
    previous_level = Rails.logger.level
    Rails.logger.level = Logger::FATAL

    organization = Organization.first
    all_member_ids = organization.members.non_suspended.pluck(:id)
    admin_member_ids = organization.members.admins.non_suspended.pluck(:id)

    puts "Total Admin Message Count: #{ORG_ADMIN_MESSAGES_COUNT}"
    DataPopulator.benchmark_wrapper "Populating Admin Messages for Organization" do
      ORG_ADMIN_MESSAGES_COUNT.times do
        create_admin_message!(organization,
          sender_id: admin_member_ids.sample,
          receiver_ids: all_member_ids.sample(rand(MAX_RECEIVERS_PER_MESSAGE) + 1),
          subject: Populator.words(8..12),
          content: Populator.paragraphs(1..3),
          auto_email: false
          )
      end
    end

    ActionMailer::Base.perform_deliveries = true
    Rails.logger.level = previous_level
  end

  private

  def create_admin_message!(organization, attrs = {})
    receiver_ids = attrs.delete(:receiver_ids)
    admin_message = organization.admin_messages.build(attrs)
    admin_message.receiver_ids = receiver_ids
    admin_message.save!
    DataPopulator.dot
  end
end