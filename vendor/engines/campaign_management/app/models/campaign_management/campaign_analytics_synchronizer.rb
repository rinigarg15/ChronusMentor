# https://github.com/mailgun/mailgun-ruby
# http://stackoverflow.com/questions/10733717/initializing-ruby-singleton
require "singleton"
require 'mailgun'

class CampaignManagement::CampaignAnalyticsSynchronizer
  include Singleton

  DEFAULT_START_TIME = 1.week
  # We can support time range in the future

  MAX_MAILGUN_EVENTS = 100

  def sync
    events_text = ChronusMentorMailgun::Event.get_events_string


    # Log the number of requests making - AP-5489
    # Am using puts instead of Rails logger to capture all the logs in campaign_management_analytics_synchronizer.log
    loop_count = 0

    @mg_events.each do |mailgun_domain, mg_event|
      result = mg_event.get( {
        limit: MAX_MAILGUN_EVENTS,
        begin: get_start_time,
        end: Time.now.to_i,
        event: events_text
      } )

      while !(items_array = result.to_h['items']).empty?
        loop_count += 1
        puts "Mailgun Query Count - #{loop_count}"

        BlockExecutor.iterate_fail_safe(items_array) do | item |
          next unless has_campaign_info?(item)

          CampaignManagement::EmailEventLog.store_campaign_event_data(item, mailgun_domain)
        end
        result = mg_event.next
      end
    end
  end

  private

  def initialize
    @mg_client = Mailgun::Client.new(APP_CONFIG[:mailgun_api_key])
    @mg_events = {}
    get_mailgun_domains_to_parse.each do |mailgun_domain|
      @mg_events[mailgun_domain] = Mailgun::Events.new(@mg_client, mailgun_domain)
    end
  end

  def get_mailgun_domains_to_parse
    source_audit_keys = Organization.where.not(source_audit_key: nil).pluck(:source_audit_key)
    migrated_envs = source_audit_keys.collect do |source_audit_key|
      source_audit_key.split("_").first
    end
    migrated_mailgun_domains = migrated_envs.uniq.collect do |env|
      MAILGUN_DOMAIN_ENVIRONMENT_MAP[env]
    end
    ([MAILGUN_DOMAIN] + migrated_mailgun_domains).uniq
  end

  def get_start_time
    latest_email_event = CampaignManagement::EmailEventLog.maximum(:timestamp)
    latest_email_event.nil? ? DEFAULT_START_TIME.ago.to_i : latest_email_event.to_i
  end

  def has_campaign_info?(item)
    return false if item['user-variables'].blank?
    item['user-variables']['campaign'] || item['user-variables']['admin_message_id'] ? true : false
  end
end
